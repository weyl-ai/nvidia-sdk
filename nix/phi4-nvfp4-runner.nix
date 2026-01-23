# Phi-4 NVFP4 runner using TensorRT-LLM
# Usage: nix run .#phi4-nvfp4 -- "Hello, my name is"
{
  lib,
  writeShellApplication,
  python312,
  openmpi,
  tritonserver-trtllm,
  cuda,
}:

let
  python = python312;

  # Python script for Phi-4 NVFP4 inference
  phi4Script = ''
#!/usr/bin/env python3
"""
Phi-4 NVFP4 inference using TensorRT-LLM high-level API.

Supports both text-only (Phi-4-reasoning-plus-NVFP4) and multimodal models.
The model is automatically downloaded from HuggingFace on first run.
"""

import argparse
import sys
import os

def main():
    parser = argparse.ArgumentParser(description="Run Phi-4 NVFP4 with TensorRT-LLM")
    parser.add_argument("prompt", nargs="?", default="Hello, my name is",
                        help="Input prompt (default: 'Hello, my name is')")
    parser.add_argument("--model", "-m", default="nvidia/Phi-4-reasoning-plus-NVFP4",
                        choices=[
                            "nvidia/Phi-4-reasoning-plus-NVFP4",
                            "nvidia/Phi-4-multimodal-instruct-NVFP4",
                        ],
                        help="Model to use (default: nvidia/Phi-4-reasoning-plus-NVFP4)")
    parser.add_argument("--max-tokens", "-n", type=int, default=256,
                        help="Maximum tokens to generate (default: 256)")
    parser.add_argument("--temperature", "-t", type=float, default=0.7,
                        help="Sampling temperature (default: 0.7)")
    parser.add_argument("--top-p", type=float, default=0.95,
                        help="Top-p sampling (default: 0.95)")
    parser.add_argument("--interactive", "-i", action="store_true",
                        help="Interactive chat mode")
    parser.add_argument("--system-prompt", "-s", default=None,
                        help="System prompt for chat mode")
    args = parser.parse_args()

    # Import TensorRT-LLM
    try:
        from tensorrt_llm import LLM, SamplingParams
    except ImportError as e:
        print(f"Error importing TensorRT-LLM: {e}", file=sys.stderr)
        print("Make sure you're running on a system with NVIDIA driver installed.", file=sys.stderr)
        sys.exit(1)

    print(f"Loading model: {args.model}", file=sys.stderr)
    print("(First run will download the model from HuggingFace)", file=sys.stderr)

    # For multimodal model, need trust_remote_code
    trust_remote_code = "multimodal" in args.model

    # Initialize the LLM
    # Note: The model name on HF ends with -NVFP4 but the LLM API expects -FP4
    model_name = args.model.replace("-NVFP4", "-FP4")
    
    llm = LLM(
        model=model_name,
        trust_remote_code=trust_remote_code,
    )

    sampling_params = SamplingParams(
        temperature=args.temperature,
        top_p=args.top_p,
        max_tokens=args.max_tokens,
    )

    if args.interactive:
        # Interactive chat mode
        print("\n=== Phi-4 NVFP4 Interactive Mode ===", file=sys.stderr)
        print("Type 'quit' or 'exit' to end the session.", file=sys.stderr)
        print("Type 'clear' to reset conversation history.", file=sys.stderr)
        print("=" * 40, file=sys.stderr)

        history = []
        if args.system_prompt:
            history.append({"role": "system", "content": args.system_prompt})

        while True:
            try:
                user_input = input("\nYou: ").strip()
            except (EOFError, KeyboardInterrupt):
                print("\nGoodbye!")
                break

            if not user_input:
                continue
            if user_input.lower() in ("quit", "exit"):
                print("Goodbye!")
                break
            if user_input.lower() == "clear":
                history = []
                if args.system_prompt:
                    history.append({"role": "system", "content": args.system_prompt})
                print("Conversation history cleared.", file=sys.stderr)
                continue

            # Build prompt from history
            history.append({"role": "user", "content": user_input})
            
            # Format as chat
            prompt = ""
            for msg in history:
                if msg["role"] == "system":
                    prompt += f"<|system|>\n{msg['content']}<|end|>\n"
                elif msg["role"] == "user":
                    prompt += f"<|user|>\n{msg['content']}<|end|>\n"
                elif msg["role"] == "assistant":
                    prompt += f"<|assistant|>\n{msg['content']}<|end|>\n"
            prompt += "<|assistant|>\n"

            outputs = llm.generate([prompt], sampling_params)
            response = outputs[0].outputs[0].text.strip()
            
            print(f"\nPhi-4: {response}")
            history.append({"role": "assistant", "content": response})
    else:
        # Single prompt mode
        prompts = [args.prompt]
        
        print(f"\nGenerating response...", file=sys.stderr)
        outputs = llm.generate(prompts, sampling_params)

        for output in outputs:
            prompt = output.prompt
            generated_text = output.outputs[0].text
            print(f"\nPrompt: {prompt}")
            print(f"Response: {generated_text}")

if __name__ == "__main__":
    main()
'';

  # Write the script to a file so mpirun can find it
  phi4ScriptFile = builtins.toFile "phi4_nvfp4_inference.py" phi4Script;

in
writeShellApplication {
  name = "phi4-nvfp4";
  
  runtimeInputs = [ python openmpi ];
  
  text = ''
    # Set up environment for TensorRT-LLM
    export PYTHONPATH="${tritonserver-trtllm}/python''${PYTHONPATH:+:$PYTHONPATH}"
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:${tritonserver-trtllm}/lib:${tritonserver-trtllm}/python/tensorrt_llm/libs:${python}/lib:${cuda}/lib:${openmpi}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export CUDA_HOME="${cuda}"
    
    # Suppress torch warnings about CUDA arch
    export TORCH_CUDA_ARCH_LIST="9.0;10.0;12.0"
    
    # Run with mpirun for TensorRT-LLM compatibility
    exec mpirun -np 1 --oversubscribe --allow-run-as-root \
      ${python}/bin/python ${phi4ScriptFile} "$@"
  '';

  meta = {
    description = "Run Phi-4 NVFP4 quantized model with TensorRT-LLM";
    longDescription = ''
      Phi-4 NVFP4 runner using TensorRT-LLM high-level API.
      
      Supported models:
      - nvidia/Phi-4-reasoning-plus-NVFP4 (default, text-only)
      - nvidia/Phi-4-multimodal-instruct-NVFP4 (multimodal)
      
      Usage:
        nix run .#phi4-nvfp4 -- "What is the meaning of life?"
        nix run .#phi4-nvfp4 -- --interactive
        nix run .#phi4-nvfp4 -- -m nvidia/Phi-4-multimodal-instruct-NVFP4 "Describe this image"
      
      Requirements:
      - NVIDIA Blackwell GPU (B100/B200) for native NVFP4 support
      - NVIDIA driver 580+ installed
      - ~8GB VRAM for Phi-4 NVFP4
    '';
    mainProgram = "phi4-nvfp4";
  };
}
