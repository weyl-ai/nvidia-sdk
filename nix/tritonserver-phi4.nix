# Triton Inference Server for Phi-4 FP4 on Blackwell
# Uses Python backend with TensorRT-LLM LLM API (auto-caches engine)
#
# Usage: nix run .#tritonserver-phi4
{
  lib,
  writeShellApplication,
  writeTextFile,
  python312,
  openmpi,
  tritonserver-trtllm,
  cuda,
}:

let
  python = python312;
  triton = tritonserver-trtllm;

  # Python model.py for the python backend
  modelPy = writeTextFile {
    name = "model.py";
    text = ''
import json
import numpy as np
import triton_python_backend_utils as pb_utils

class TritonPythonModel:
    """Phi-4 FP4 model using TensorRT-LLM LLM API.
    
    Engine is cached automatically by TRT-LLM on first load.
    Cache location: ~/.cache/tensorrt_llm/
    """

    def initialize(self, args):
        self.model_config = model_config = json.loads(args["model_config"])
        
        # Get parameters
        params = model_config.get("parameters", {})
        model_name = params.get("model", {}).get("string_value", "nvidia/Phi-4-reasoning-plus-FP4")
        tp_size = int(params.get("tensor_parallel_size", {}).get("string_value", "1"))
        
        # Import and initialize TensorRT-LLM
        from tensorrt_llm import LLM, SamplingParams
        
        print(f"[Phi4] Loading model: {model_name}")
        print(f"[Phi4] Tensor parallelism: {tp_size}")
        print(f"[Phi4] Engine will be cached in ~/.cache/tensorrt_llm/")
        
        self.llm = LLM(
            model=model_name,
            tensor_parallel_size=tp_size,
        )
        self.SamplingParams = SamplingParams
        print("[Phi4] Model loaded successfully")

    def execute(self, requests):
        responses = []
        
        for request in requests:
            # Get inputs
            text_input = pb_utils.get_input_tensor_by_name(request, "text_input")
            prompts = [t.decode("utf-8") for t in text_input.as_numpy().flatten()]
            
            # Get optional parameters
            max_tokens = self._get_scalar(request, "max_tokens", 256)
            temperature = self._get_scalar(request, "temperature", 0.8)
            top_p = self._get_scalar(request, "top_p", 0.95)
            
            # Generate
            sampling_params = self.SamplingParams(
                max_tokens=int(max_tokens),
                temperature=float(temperature),
                top_p=float(top_p),
            )
            
            outputs = self.llm.generate(prompts, sampling_params)
            
            # Collect results
            results = [out.outputs[0].text for out in outputs]
            
            # Create output tensor
            out_tensor = pb_utils.Tensor(
                "text_output",
                np.array(results, dtype=object)
            )
            
            responses.append(pb_utils.InferenceResponse([out_tensor]))
        
        return responses

    def _get_scalar(self, request, name, default):
        tensor = pb_utils.get_input_tensor_by_name(request, name)
        if tensor is None:
            return default
        return tensor.as_numpy().flatten()[0]

    def finalize(self):
        print("[Phi4] Shutting down")
        del self.llm
'';
  };

  # Config for python backend
  configPbtxt = writeTextFile {
    name = "config.pbtxt";
    text = ''
name: "phi4"
backend: "python"
max_batch_size: 8

input [
  {
    name: "text_input"
    data_type: TYPE_STRING
    dims: [ -1 ]
  },
  {
    name: "max_tokens"
    data_type: TYPE_INT32
    dims: [ 1 ]
    optional: true
  },
  {
    name: "temperature"
    data_type: TYPE_FP32
    dims: [ 1 ]
    optional: true
  },
  {
    name: "top_p"
    data_type: TYPE_FP32
    dims: [ 1 ]
    optional: true
  }
]

output [
  {
    name: "text_output"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }
]

instance_group [
  {
    count: 1
    kind: KIND_GPU
    gpus: [ 0 ]
  }
]

parameters {
  key: "model"
  value: { string_value: "nvidia/Phi-4-reasoning-plus-FP4" }
}
parameters {
  key: "tensor_parallel_size"
  value: { string_value: "1" }
}

dynamic_batching {
  max_queue_delay_microseconds: 100000
}
'';
  };

in
writeShellApplication {
  name = "tritonserver-phi4";
  
  runtimeInputs = [ python openmpi ];
  
  text = ''
    set -euo pipefail

    MODEL_REPO="''${XDG_RUNTIME_DIR:-/tmp}/triton-phi4-repo"
    
    echo "Setting up model repository at $MODEL_REPO"
    rm -rf "$MODEL_REPO"
    mkdir -p "$MODEL_REPO/phi4/1"
    
    # Copy config and model
    cp ${configPbtxt} "$MODEL_REPO/phi4/config.pbtxt"
    cp ${modelPy} "$MODEL_REPO/phi4/1/model.py"

    echo ""
    echo "=== Triton Inference Server for Phi-4 FP4 ==="
    echo "Model: nvidia/Phi-4-reasoning-plus-FP4"
    echo "Backend: python (with TensorRT-LLM LLM API)"
    echo "Hardware: Blackwell SM120 (native FP4 @ 2 PFLOPS)"
    echo ""
    echo "Engine cache: ~/.cache/tensorrt_llm/"
    echo "(First run builds engine, subsequent runs use cache)"
    echo ""
    echo "Endpoints:"
    echo "  Health:  http://localhost:8000/v2/health/ready"
    echo "  Models:  http://localhost:8000/v2/models"
    echo "  Infer:   POST http://localhost:8000/v2/models/phi4/infer"
    echo ""
    echo "Example query:"
    echo "  curl -X POST localhost:8000/v2/models/phi4/infer -H 'Content-Type: application/json' -d '{\"inputs\":[{\"name\":\"text_input\",\"shape\":[1],\"datatype\":\"BYTES\",\"data\":[\"What is 2+2?\"]}]}'"
    echo ""
    echo "Starting server..."
    echo ""

    export PYTHONPATH="${triton}/python''${PYTHONPATH:+:$PYTHONPATH}"
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:${triton}/lib:${triton}/python/tensorrt_llm/libs:${cuda}/lib64:${openmpi}/lib:${python}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export CUDA_HOME="${cuda}"
    
    # Use mpirun for TRT-LLM compatibility
    exec mpirun -np 1 --oversubscribe --allow-run-as-root \
      ${triton}/bin/tritonserver \
        --model-repository="$MODEL_REPO" \
        --backend-directory="${triton}/backends" \
        --http-port=8000 \
        --grpc-port=8001 \
        --metrics-port=8002 \
        --log-verbose=1 \
        "$@"
  '';

  meta = {
    description = "Triton Inference Server serving Phi-4 FP4 on Blackwell";
    mainProgram = "tritonserver-phi4";
  };
}
