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

  phi4Script = ''
#!/usr/bin/env python3
"""
Phi-4 FP4 inference using TensorRT-LLM high-level API.
Runs on Blackwell (SM120) with native FP4 support - 2 PFLOPS dense.
"""

import argparse
import sys

def main():
    parser = argparse.ArgumentParser(description="Run Phi-4 FP4 with TensorRT-LLM")
    parser.add_argument("prompt", nargs="?", default="Hello, my name is",
                        help="Input prompt")
    parser.add_argument("--max-tokens", "-n", type=int, default=256,
                        help="Maximum tokens to generate")
    parser.add_argument("--temperature", "-t", type=float, default=0.8,
                        help="Sampling temperature")
    parser.add_argument("--top-p", type=float, default=0.95,
                        help="Top-p sampling")
    args = parser.parse_args()

    from tensorrt_llm import LLM, SamplingParams

    print("Loading nvidia/Phi-4-reasoning-plus-FP4...", file=sys.stderr)

    llm = LLM(model="nvidia/Phi-4-reasoning-plus-FP4")

    sampling_params = SamplingParams(
        temperature=args.temperature,
        top_p=args.top_p,
        max_tokens=args.max_tokens,
    )

    outputs = llm.generate([args.prompt], sampling_params)

    for output in outputs:
        print(f"Prompt: {output.prompt!r}")
        print(f"Generated: {output.outputs[0].text!r}")

if __name__ == "__main__":
    main()
'';

  phi4ScriptFile = builtins.toFile "phi4_fp4.py" phi4Script;

in
writeShellApplication {
  name = "phi4-nvfp4";
  
  runtimeInputs = [ python openmpi ];
  
  text = ''
    export PYTHONPATH="${tritonserver-trtllm}/python''${PYTHONPATH:+:$PYTHONPATH}"
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:${tritonserver-trtllm}/lib:${tritonserver-trtllm}/python/tensorrt_llm/libs:${cuda}/lib64:${openmpi}/lib:${python}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export CUDA_HOME="${cuda}"
    
    exec mpirun -np 1 --oversubscribe --allow-run-as-root \
      ${python}/bin/python ${phi4ScriptFile} "$@"
  '';

  meta = {
    description = "Run Phi-4 FP4 on Blackwell (SM120) with TensorRT-LLM";
    mainProgram = "phi4-nvfp4";
  };
}
