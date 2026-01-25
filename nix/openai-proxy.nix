# OpenAI-compatible proxy for TensorRT-LLM backend
#
# This proxy handles:
# - Chat template application (transformers)
# - Tokenization/detokenization (transformers)
# - GRPC streaming to tensorrt_llm backend
# - SSE streaming to OpenAI clients
#
# The heavy lifting (inference) is done by Triton/TensorRT-LLM.
# Tokenization will move to C++ (sentencepiece/tiktoken) later.
#
# Usage:
#   nix run .#openai-qwen3
#   # Then configure OpenWebUI with base URL: http://localhost:9000/v1

{
  lib,
  writeShellApplication,
  writeTextFile,
  python312,
  tritonserver-trtllm,
  tokenizerModel,   # HuggingFace model ID for tokenizer
  modelName,        # Model name for API responses
  tritonGrpcPort ? 8001,
  openaiPort ? 9000,
}:

let
  python = python312;
  
  proxyScript = writeTextFile {
    name = "openai-proxy.py";
    text = ''
#!/usr/bin/env python3
"""
OpenAI-compatible proxy for TensorRT-LLM backend.

Handles tokenization in Python (for now), streams tokens from tensorrt_llm,
and detokenizes incrementally for SSE streaming.
"""
import argparse
import json
import queue
import time
import uuid
from functools import partial
from typing import Generator, Optional

import numpy as np
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from transformers import AutoTokenizer

import tritonclient.grpc as grpcclient
from tritonclient.utils import InferenceServerException, np_to_triton_dtype


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatCompletionRequest(BaseModel):
    model: str
    messages: list[ChatMessage]
    temperature: Optional[float] = 0.7
    top_p: Optional[float] = 0.9
    max_tokens: Optional[int] = 2048
    stream: Optional[bool] = False


class UserData:
    """Container for streaming callback results."""
    def __init__(self):
        self._completed_requests = queue.Queue()


def streaming_callback(user_data: UserData, result, error):
    """Callback for GRPC streaming responses."""
    if error:
        user_data._completed_requests.put(error)
    else:
        user_data._completed_requests.put(result)


def prepare_tensor(name: str, data: np.ndarray) -> grpcclient.InferInput:
    """Create a Triton GRPC input tensor."""
    dtype_str = np_to_triton_dtype(data.dtype)
    tensor = grpcclient.InferInput(name, list(data.shape), dtype_str)
    tensor.set_data_from_numpy(data)
    return tensor


class OpenAIProxy:
    def __init__(self, triton_url: str, model_name: str, tokenizer_path: str):
        self.triton_url = triton_url
        self.model_name = model_name
        self.created = int(time.time())
        
        print(f"Loading tokenizer from {tokenizer_path}...")
        self.tokenizer = AutoTokenizer.from_pretrained(
            tokenizer_path, trust_remote_code=True
        )
        
        # Get special token IDs
        self.end_id = self.tokenizer.eos_token_id or 151643
        self.pad_id = self.tokenizer.pad_token_id or self.end_id
        
        print(f"Tokenizer loaded. end_id={self.end_id}, pad_id={self.pad_id}")

    def apply_chat_template(self, messages: list[ChatMessage]) -> str:
        """Apply HF chat template to messages."""
        msg_dicts = [{"role": m.role, "content": m.content} for m in messages]
        try:
            return self.tokenizer.apply_chat_template(
                msg_dicts, tokenize=False, add_generation_prompt=True
            )
        except Exception as e:
            print(f"Chat template failed: {e}, using fallback")
            return "\n".join(f"{m.role}: {m.content}" for m in messages) + "\nassistant:"

    def tokenize(self, text: str) -> np.ndarray:
        """Tokenize text to input_ids."""
        ids = self.tokenizer.encode(text, add_special_tokens=False)
        return np.array(ids, dtype=np.int32)

    def detokenize(self, token_ids: list[int]) -> str:
        """Decode token_ids to text."""
        return self.tokenizer.decode(token_ids, skip_special_tokens=True)

    def generate_streaming(
        self,
        prompt: str,
        max_tokens: int,
        temperature: float,
        top_p: float,
    ) -> Generator[str, None, None]:
        """Stream generation via Triton GRPC.
        
        TensorRT-LLM returns ONE token per response in streaming mode.
        We accumulate tokens and incrementally detokenize.
        """
        
        input_ids = self.tokenize(prompt)
        input_len = len(input_ids)
        
        # Prepare inputs for tensorrt_llm backend
        # All tensors need batch dimension
        inputs = [
            prepare_tensor("input_ids", input_ids.reshape(1, -1)),
            prepare_tensor("input_lengths", np.array([[input_len]], dtype=np.int32)),
            prepare_tensor("request_output_len", np.array([[max_tokens]], dtype=np.int32)),
            prepare_tensor("end_id", np.array([[self.end_id]], dtype=np.int32)),
            prepare_tensor("pad_id", np.array([[self.pad_id]], dtype=np.int32)),
            prepare_tensor("streaming", np.array([[True]], dtype=bool)),
            prepare_tensor("temperature", np.array([[temperature]], dtype=np.float32)),
            prepare_tensor("runtime_top_p", np.array([[top_p]], dtype=np.float32)),
        ]
        
        outputs = [
            grpcclient.InferRequestedOutput("output_ids"),
            grpcclient.InferRequestedOutput("sequence_length"),
        ]
        
        user_data = UserData()
        
        # Accumulate generated tokens for incremental detokenization
        gen_tokens = []
        prev_text = ""
        
        with grpcclient.InferenceServerClient(url=self.triton_url) as client:
            # Start streaming with callback
            client.start_stream(callback=partial(streaming_callback, user_data))
            
            try:
                # Send inference request
                client.async_stream_infer(
                    model_name="tensorrt_llm",
                    inputs=inputs,
                    outputs=outputs,
                    request_id=str(uuid.uuid4()),
                )
                
                # Process streaming responses
                # TensorRT-LLM returns ONE token per response
                while True:
                    try:
                        result = user_data._completed_requests.get(timeout=60.0)
                    except queue.Empty:
                        print("Timeout waiting for response")
                        break
                    
                    if isinstance(result, InferenceServerException):
                        print(f"Inference error: {result}")
                        break
                    
                    # Get output token - shape is [1, 1, 1] (batch, beam, 1 token)
                    output_ids = result.as_numpy("output_ids")
                    
                    if output_ids is None:
                        continue
                    
                    # Extract the single token
                    token = int(output_ids[0, 0, 0])
                    
                    # Check for end token BEFORE accumulating
                    if token == self.end_id:
                        break
                    
                    # Accumulate token
                    gen_tokens.append(token)
                    
                    # Detokenize all generated tokens so far
                    full_text = self.detokenize(gen_tokens)
                    
                    # Yield only new text since last response
                    if len(full_text) > len(prev_text):
                        new_text = full_text[len(prev_text):]
                        prev_text = full_text
                        yield new_text
                    
                    # Check max tokens
                    if len(gen_tokens) >= max_tokens:
                        break
                        
            finally:
                client.stop_stream()

    def generate(
        self,
        prompt: str,
        max_tokens: int,
        temperature: float,
        top_p: float,
    ) -> str:
        """Non-streaming generation."""
        chunks = []
        for chunk in self.generate_streaming(prompt, max_tokens, temperature, top_p):
            chunks.append(chunk)
        return "".join(chunks)


def create_app(proxy: OpenAIProxy) -> FastAPI:
    app = FastAPI(title=f"OpenAI Proxy - {proxy.model_name}")

    @app.get("/health")
    async def health():
        return {"status": "ok"}

    @app.get("/v1/models")
    async def list_models():
        return {
            "object": "list",
            "data": [{
                "id": proxy.model_name,
                "object": "model",
                "created": proxy.created,
                "owned_by": "nvidia",
            }]
        }

    @app.post("/v1/chat/completions")
    async def chat_completions(request: ChatCompletionRequest):
        prompt = proxy.apply_chat_template(request.messages)
        request_id = f"chatcmpl-{uuid.uuid4().hex[:8]}"
        
        max_tokens = request.max_tokens or 2048
        temperature = request.temperature or 0.7
        top_p = request.top_p or 0.9
        
        if request.stream:
            def stream_response():
                try:
                    for chunk in proxy.generate_streaming(prompt, max_tokens, temperature, top_p):
                        if chunk:
                            data = {
                                "id": request_id,
                                "object": "chat.completion.chunk",
                                "created": int(time.time()),
                                "model": request.model,
                                "choices": [{
                                    "index": 0,
                                    "delta": {"content": chunk},
                                    "finish_reason": None,
                                }]
                            }
                            yield f"data: {json.dumps(data)}\n\n"
                except Exception as e:
                    print(f"Streaming error: {e}")
                    import traceback
                    traceback.print_exc()
                
                # Final message
                final = {
                    "id": request_id,
                    "object": "chat.completion.chunk",
                    "created": int(time.time()),
                    "model": request.model,
                    "choices": [{
                        "index": 0,
                        "delta": {},
                        "finish_reason": "stop",
                    }]
                }
                yield f"data: {json.dumps(final)}\n\n"
                yield "data: [DONE]\n\n"
            
            return StreamingResponse(
                stream_response(),
                media_type="text/event-stream",
            )
        else:
            text = proxy.generate(prompt, max_tokens, temperature, top_p)
            return {
                "id": request_id,
                "object": "chat.completion",
                "created": int(time.time()),
                "model": request.model,
                "choices": [{
                    "index": 0,
                    "message": {"role": "assistant", "content": text},
                    "finish_reason": "stop",
                }],
                "usage": {
                    "prompt_tokens": -1,
                    "completion_tokens": -1,
                    "total_tokens": -1,
                }
            }

    return app


def main():
    parser = argparse.ArgumentParser(description="OpenAI proxy for TensorRT-LLM")
    parser.add_argument("--port", type=int, default=${toString openaiPort})
    parser.add_argument("--triton-url", type=str, default="localhost:${toString tritonGrpcPort}")
    parser.add_argument("--model-name", type=str, default="${modelName}")
    parser.add_argument("--tokenizer", type=str, default="${tokenizerModel}")
    args = parser.parse_args()
    
    proxy = OpenAIProxy(args.triton_url, args.model_name, args.tokenizer)
    app = create_app(proxy)
    
    print(f"""
╔══════════════════════════════════════════════════════════════════╗
║  OpenAI Proxy: {args.model_name}
║  Backend: grpc://{args.triton_url} (tensorrt_llm)
╠══════════════════════════════════════════════════════════════════╣
║  http://localhost:{args.port}/v1/chat/completions
║  http://localhost:{args.port}/v1/models
╠══════════════════════════════════════════════════════════════════╣
║  OpenWebUI: Base URL = http://localhost:{args.port}/v1
╚══════════════════════════════════════════════════════════════════╝
""")
    
    uvicorn.run(app, host="0.0.0.0", port=args.port, log_level="info")


if __name__ == "__main__":
    main()
'';
  };

in
writeShellApplication {
  name = "openai-${modelName}";
  runtimeInputs = [ python ];
  text = ''
    # Add tritonclient from tritonserver
    export PYTHONPATH="${tritonserver-trtllm}/python''${PYTHONPATH:+:$PYTHONPATH}"
    exec ${python}/bin/python ${proxyScript} "$@"
  '';
  meta = {
    description = "OpenAI-compatible proxy for ${modelName} (streaming, OpenWebUI)";
    mainProgram = "openai-${modelName}";
  };
}
