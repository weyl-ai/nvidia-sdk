# OpenAI-compatible proxy for TensorRT-LLM native backend
#
# Connects to Triton's GRPC endpoint with the tensorrtllm backend
# and exposes an OpenAI-compatible REST API with streaming support.
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
  tokenizer,        # Path to HF model for tokenizer
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
OpenAI-compatible proxy for TensorRT-LLM native backend.

Connects to Triton GRPC with tensorrtllm backend (streaming decoupled mode)
and exposes OpenAI chat/completions API with SSE streaming.
"""
import argparse
import asyncio
import json
import time
import uuid
from typing import AsyncGenerator, Optional

import grpc
import numpy as np
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from transformers import AutoTokenizer

# Triton GRPC protos
import tritonclient.grpc.aio as grpcclient


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


class OpenAIProxy:
    def __init__(self, triton_url: str, model_name: str, tokenizer_path: str):
        self.triton_url = triton_url
        self.model_name = model_name
        self.created = int(time.time())
        
        print(f"Loading tokenizer from {tokenizer_path}...")
        self.tokenizer = AutoTokenizer.from_pretrained(tokenizer_path, trust_remote_code=True)
        
        # Token IDs for generation control
        self.end_id = self.tokenizer.eos_token_id or 151645
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

    def tokenize(self, text: str) -> list[int]:
        """Tokenize text to input_ids."""
        return self.tokenizer.encode(text, add_special_tokens=False)

    def detokenize(self, token_ids: list[int]) -> str:
        """Decode token_ids to text."""
        return self.tokenizer.decode(token_ids, skip_special_tokens=True)

    async def generate_stream(
        self,
        prompt: str,
        max_tokens: int,
        temperature: float,
        top_p: float,
    ) -> AsyncGenerator[str, None]:
        """Stream generation via Triton GRPC with tensorrtllm backend."""
        
        input_ids = self.tokenize(prompt)
        input_len = len(input_ids)
        
        async with grpcclient.InferenceServerClient(url=self.triton_url) as client:
            # Prepare inputs for tensorrtllm backend
            inputs = [
                grpcclient.InferInput("input_ids", [1, input_len], "INT32"),
                grpcclient.InferInput("input_lengths", [1], "INT32"),
                grpcclient.InferInput("request_output_len", [1], "INT32"),
                grpcclient.InferInput("end_id", [1], "INT32"),
                grpcclient.InferInput("pad_id", [1], "INT32"),
                grpcclient.InferInput("streaming", [1], "BOOL"),
                grpcclient.InferInput("temperature", [1], "FP32"),
                grpcclient.InferInput("top_p", [1], "FP32"),
            ]
            
            inputs[0].set_data_from_numpy(np.array([input_ids], dtype=np.int32))
            inputs[1].set_data_from_numpy(np.array([input_len], dtype=np.int32))
            inputs[2].set_data_from_numpy(np.array([max_tokens], dtype=np.int32))
            inputs[3].set_data_from_numpy(np.array([self.end_id], dtype=np.int32))
            inputs[4].set_data_from_numpy(np.array([self.pad_id], dtype=np.int32))
            inputs[5].set_data_from_numpy(np.array([True], dtype=bool))
            inputs[6].set_data_from_numpy(np.array([temperature], dtype=np.float32))
            inputs[7].set_data_from_numpy(np.array([top_p], dtype=np.float32))
            
            outputs = [grpcclient.InferRequestedOutput("output_ids")]
            
            # Stream responses (decoupled mode)
            prev_output_len = 0
            async for response in client.stream_infer(
                model_name="tensorrt_llm",
                inputs=inputs,
                outputs=outputs,
            ):
                result, error = response
                if error:
                    raise HTTPException(status_code=500, detail=str(error))
                
                output_ids = result.as_numpy("output_ids")
                if output_ids is not None:
                    # Get new tokens since last response
                    current_ids = output_ids.flatten().tolist()
                    # Skip input tokens and already-yielded tokens
                    new_ids = current_ids[input_len + prev_output_len:]
                    if new_ids:
                        new_text = self.detokenize(new_ids)
                        prev_output_len = len(current_ids) - input_len
                        yield new_text

    async def generate(
        self,
        prompt: str,
        max_tokens: int,
        temperature: float,
        top_p: float,
    ) -> str:
        """Non-streaming generation."""
        chunks = []
        async for chunk in self.generate_stream(prompt, max_tokens, temperature, top_p):
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
            async def stream_response() -> AsyncGenerator[str, None]:
                async for chunk in proxy.generate_stream(prompt, max_tokens, temperature, top_p):
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
            text = await proxy.generate(prompt, max_tokens, temperature, top_p)
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
    parser.add_argument("--tokenizer", type=str, default="${tokenizer}")
    args = parser.parse_args()
    
    proxy = OpenAIProxy(args.triton_url, args.model_name, args.tokenizer)
    app = create_app(proxy)
    
    print(f"""
╔══════════════════════════════════════════════════════════════════╗
║  OpenAI Proxy: {args.model_name}
║  Backend: grpc://{args.triton_url}
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
    export PYTHONPATH="${tritonserver-trtllm}/python''${PYTHONPATH:+:$PYTHONPATH}"
    exec ${python}/bin/python ${proxyScript} "$@"
  '';
  meta = {
    description = "OpenAI-compatible proxy for ${modelName} (streaming, OpenWebUI)";
    mainProgram = "openai-${modelName}";
  };
}
