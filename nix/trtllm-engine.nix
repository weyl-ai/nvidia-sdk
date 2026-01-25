# TensorRT-LLM Engine Builder
#
# Builds TRT-LLM engines using the canonical workflow:
#   HuggingFace Model → Model.from_hugging_face() → save_checkpoint() → trtllm-build → Triton
#
# These are IMPURE builds that require GPU access (__noChroot = true).
#
# Usage:
#   engines = callPackage ./trtllm-engine.nix { };
#
#   # For pre-quantized NVFP4 models (nvidia/*)
#   qwen3-engine = engines.mkEngine {
#     name = "qwen3-32b-nvfp4";
#     hfModel = /path/to/nvidia/Qwen3-32B-NVFP4;  # or use mkHfModel
#     modelType = "qwen";
#     tensorParallelSize = 4;
#   };
#
#   qwen3-triton = engines.mkTritonRepo {
#     name = "qwen3-32b";
#     engine = qwen3-engine;
#     tokenizer = /path/to/nvidia/Qwen3-32B-NVFP4;
#   };

{
  lib,
  stdenvNoCC,
  stdenv,
  runCommand,
  writeTextFile,
  writeShellApplication,
  cacert,
  git,
  git-lfs,
  python312,
  openmpi,
  tritonserver-trtllm,
  cuda,
}:

let
  python = python312;
  triton = tritonserver-trtllm;

  # Model class mapping for TRT-LLM
  modelClasses = {
    qwen = "QWenForCausalLM";
    llama = "LLaMAForCausalLM";
    phi = "PhiForCausalLM";
    mixtral = "MixtralForCausalLM";
    gemma = "GemmaForCausalLM";
  };

  # Environment setup for TRT-LLM commands
  envSetup = ''
    export PYTHONPATH="${triton}/python''${PYTHONPATH:+:$PYTHONPATH}"
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:${triton}/lib:${triton}/tensorrt_llm/lib:${cuda}/lib64:${openmpi}/lib:${python}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export CUDA_HOME="${cuda}"
    export HOME="$TMPDIR/home"
    export HF_HOME="$TMPDIR/hf_cache"
    export TLLM_LOG_LEVEL="WARNING"
    mkdir -p "$HOME" "$HF_HOME"
  '';

in
rec {
  inherit python openmpi triton cuda envSetup;

  # ============================================================================
  # mkHfModel: Download a HuggingFace model (Fixed Output Derivation)
  # ============================================================================
  mkHfModel =
    {
      name,           # e.g. "qwen3-32b-nvfp4"
      model,          # HuggingFace model ID, e.g. "nvidia/Qwen3-32B-NVFP4"
      hash,           # NAR hash of the downloaded model
      revision ? "main",
    }:
    stdenvNoCC.mkDerivation {
      pname = "hf-model-${name}";
      version = revision;

      nativeBuildInputs = [ git git-lfs cacert ];

      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash = hash;

      SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
      GIT_SSL_CAINFO = "${cacert}/etc/ssl/certs/ca-bundle.crt";

      buildCommand = ''
        export HOME=$TMPDIR
        git lfs install --skip-repo
        git clone --depth 1 --branch ${revision} https://huggingface.co/${model} $out
        rm -rf $out/.git
      '';

      meta = {
        description = "HuggingFace model: ${model}";
        homepage = "https://huggingface.co/${model}";
      };
    };

  # ============================================================================
  # mkEngine: Build TensorRT engine from HuggingFace model
  # ============================================================================
  #
  # This is the ONE PATH for building TRT-LLM engines:
  #   1. Model.from_hugging_face() + save_checkpoint(): HF model → TRT-LLM checkpoint
  #   2. trtllm-build: checkpoint → TensorRT engine
  #
  mkEngine =
    {
      name,                    # e.g. "qwen3-32b-nvfp4"
      hfModel,                 # Path to HuggingFace model directory
      modelType ? "qwen",      # Model architecture: qwen, llama, phi, etc.
      dtype ? "bfloat16",
      tensorParallelSize ? 1,
      pipelineParallelSize ? 1,
      maxBatchSize ? 8,
      maxInputLen ? 8192,
      maxSeqLen ? 16384,
      maxNumTokens ? 8192,
      extraBuildArgs ? "",     # Extra args for trtllm-build
    }:
    let
      worldSize = tensorParallelSize * pipelineParallelSize;
      modelClass = modelClasses.${modelType} or (throw "Unknown model type: ${modelType}");
      gemmPlugin = dtype;
    in
    stdenv.mkDerivation {
      pname = "trtllm-engine-${name}";
      version = "1.0.0";

      # IMPURE: requires GPU for TensorRT engine compilation
      __noChroot = true;

      nativeBuildInputs = [ python openmpi ];

      buildCommand = ''
        ${envSetup}

        CHECKPOINT_DIR="$TMPDIR/checkpoint"
        mkdir -p "$CHECKPOINT_DIR" "$out"

        echo "════════════════════════════════════════════════════════════════"
        echo "Building TensorRT-LLM engine: ${name}"
        echo "════════════════════════════════════════════════════════════════"
        echo "Model: ${hfModel}"
        echo "Type: ${modelType} (${modelClass})"
        echo "TP: ${toString tensorParallelSize}, PP: ${toString pipelineParallelSize}"
        echo ""

        # ──────────────────────────────────────────────────────────────────────
        # Step 1: Convert HuggingFace model to TRT-LLM checkpoint
        # ──────────────────────────────────────────────────────────────────────
        echo "Step 1: Converting HuggingFace model to TRT-LLM checkpoint..."

        ${python}/bin/python << 'PYTHON_CONVERT'
import os
import sys

# TRT-LLM model conversion
from tensorrt_llm.models import ${modelClass}
from tensorrt_llm.mapping import Mapping

model_dir = "${hfModel}"
checkpoint_dir = os.environ["CHECKPOINT_DIR"]
tp_size = ${toString tensorParallelSize}
pp_size = ${toString pipelineParallelSize}
world_size = tp_size * pp_size

print(f"Loading model from {model_dir}...")
print(f"  Tensor Parallel: {tp_size}")
print(f"  Pipeline Parallel: {pp_size}")
print(f"  World Size: {world_size}")

# Create mapping for parallelism
mapping = Mapping(
    world_size=world_size,
    rank=0,  # We save rank 0 checkpoint, trtllm-build handles sharding
    tp_size=tp_size,
    pp_size=pp_size,
)

# Load and convert model
model = ${modelClass}.from_hugging_face(
    model_dir,
    dtype="${dtype}",
    mapping=mapping,
)

print(f"Saving checkpoint to {checkpoint_dir}...")
model.save_checkpoint(checkpoint_dir)

print("Checkpoint conversion complete!")
print("Contents:", os.listdir(checkpoint_dir))
PYTHON_CONVERT

        echo "Checkpoint created at $CHECKPOINT_DIR"
        ls -la "$CHECKPOINT_DIR/"

        # ──────────────────────────────────────────────────────────────────────
        # Step 2: Build TensorRT engine
        # ──────────────────────────────────────────────────────────────────────
        echo ""
        echo "Step 2: Building TensorRT engine..."

        ${python}/bin/python -m tensorrt_llm.commands.build \
          --checkpoint_dir "$CHECKPOINT_DIR" \
          --output_dir "$out" \
          --gemm_plugin ${gemmPlugin} \
          --max_batch_size ${toString maxBatchSize} \
          --max_input_len ${toString maxInputLen} \
          --max_seq_len ${toString maxSeqLen} \
          --max_num_tokens ${toString maxNumTokens} \
          --paged_kv_cache enable \
          --use_paged_context_fmha enable \
          ${extraBuildArgs}

        echo ""
        echo "════════════════════════════════════════════════════════════════"
        echo "Engine built successfully!"
        echo "════════════════════════════════════════════════════════════════"
        ls -la "$out/"
      '';

      meta = {
        description = "TensorRT-LLM engine for ${name}";
      };
    };

  # ============================================================================
  # mkTritonRepo: Generate Triton model repository with tensorrtllm backend
  # ============================================================================
  mkTritonRepo =
    {
      name,           # e.g. "qwen3-32b"
      engine,         # Output of mkEngine
      tokenizer,      # Path to tokenizer (usually same as HF model)
      maxBatchSize ? 8,
      batchSchedulerPolicy ? "guaranteed_no_evict",
      kvCacheFreeGpuMemFraction ? 0.9,
      enableChunkedContext ? true,
      decodingMode ? "auto",
    }:
    let
      configPbtxt = writeTextFile {
        name = "config.pbtxt";
        text = ''
          name: "tensorrt_llm"
          backend: "tensorrtllm"
          max_batch_size: ${toString maxBatchSize}

          model_transaction_policy {
            decoupled: true
          }

          dynamic_batching {
            preferred_batch_size: [ 1, 2, 4, 8 ]
            max_queue_delay_microseconds: 100
          }

          input [
            { name: "input_ids",        data_type: TYPE_INT32, dims: [ -1 ] },
            { name: "input_lengths",    data_type: TYPE_INT32, dims: [ 1 ], reshape: { shape: [ ] } },
            { name: "request_output_len", data_type: TYPE_INT32, dims: [ 1 ], reshape: { shape: [ ] } },
            { name: "end_id",           data_type: TYPE_INT32, dims: [ 1 ], reshape: { shape: [ ] }, optional: true },
            { name: "pad_id",           data_type: TYPE_INT32, dims: [ 1 ], reshape: { shape: [ ] }, optional: true },
            { name: "streaming",        data_type: TYPE_BOOL,  dims: [ 1 ], reshape: { shape: [ ] }, optional: true },
            { name: "temperature",      data_type: TYPE_FP32,  dims: [ 1 ], reshape: { shape: [ ] }, optional: true },
            { name: "top_p",            data_type: TYPE_FP32,  dims: [ 1 ], reshape: { shape: [ ] }, optional: true },
            { name: "top_k",            data_type: TYPE_INT32, dims: [ 1 ], reshape: { shape: [ ] }, optional: true }
          ]

          output [
            { name: "output_ids",       data_type: TYPE_INT32, dims: [ -1, -1 ] },
            { name: "sequence_length",  data_type: TYPE_INT32, dims: [ -1 ] },
            { name: "cum_log_probs",    data_type: TYPE_FP32,  dims: [ -1 ] },
            { name: "output_log_probs", data_type: TYPE_FP32,  dims: [ -1, -1 ] }
          ]

          instance_group [
            { count: 1, kind: KIND_CPU }
          ]

          parameters: { key: "gpt_model_type",                value: { string_value: "inflight_fused_batching" } }
          parameters: { key: "gpt_model_path",                value: { string_value: "ENGINE_PATH_PLACEHOLDER" } }
          parameters: { key: "batch_scheduler_policy",        value: { string_value: "${batchSchedulerPolicy}" } }
          parameters: { key: "kv_cache_free_gpu_mem_fraction", value: { string_value: "${toString kvCacheFreeGpuMemFraction}" } }
          ${lib.optionalString enableChunkedContext ''parameters: { key: "enable_chunked_context", value: { string_value: "true" } }''}
          parameters: { key: "decoding_mode",                 value: { string_value: "${decodingMode}" } }
        '';
      };
    in
    runCommand "triton-repo-${name}" {} ''
      mkdir -p $out/tensorrt_llm/1

      # Copy and patch config
      sed 's|ENGINE_PATH_PLACEHOLDER|${engine}|g' ${configPbtxt} > $out/tensorrt_llm/config.pbtxt

      # Create version marker
      touch $out/tensorrt_llm/1/.keep

      # Link tokenizer
      ln -s ${tokenizer} $out/tokenizer

      echo "Triton model repository created at $out"
      echo "  Engine: ${engine}"
      echo "  Tokenizer: ${tokenizer}"
    '';

  # ============================================================================
  # mkTritonServer: Create a wrapper script to run Triton with the model repo
  # ============================================================================
  mkTritonServer =
    {
      name,
      repo,           # Output of mkTritonRepo
      httpPort ? 8000,
      grpcPort ? 8001,
      metricsPort ? 8002,
      worldSize ? 1,  # For multi-GPU: number of GPUs
    }:
    writeShellApplication {
      name = "tritonserver-${name}";
      runtimeInputs = [ triton openmpi ];
      text = ''
        export LD_LIBRARY_PATH="/run/opengl-driver/lib:${triton}/lib:${triton}/tensorrt_llm/lib:${cuda}/lib64:${openmpi}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

        ${if worldSize > 1 then ''
        # Multi-GPU: launch with mpirun
        exec mpirun -np ${toString worldSize} --allow-run-as-root \
          ${triton}/bin/tritonserver \
            --model-repository=${repo} \
            --http-port=${toString httpPort} \
            --grpc-port=${toString grpcPort} \
            --metrics-port=${toString metricsPort} \
            "$@"
        '' else ''
        exec ${triton}/bin/tritonserver \
          --model-repository=${repo} \
          --http-port=${toString httpPort} \
          --grpc-port=${toString grpcPort} \
          --metrics-port=${toString metricsPort} \
          "$@"
        ''}
      '';
      meta = {
        description = "Triton Inference Server for ${name}";
        mainProgram = "tritonserver-${name}";
      };
    };

  # ============================================================================
  # Convenience: buildQwen - build engine for Qwen-family models
  # ============================================================================
  buildQwen =
    {
      name,
      hfModel,
      tensorParallelSize ? 1,
      ...
    }@args:
    let
      engineArgs = builtins.removeAttrs args [ "name" "hfModel" ];
      engine = mkEngine ({
        inherit name hfModel;
        modelType = "qwen";
      } // engineArgs);
      tritonRepo = mkTritonRepo {
        inherit name engine;
        tokenizer = hfModel;
      };
    in
    {
      inherit engine tritonRepo;
      server = mkTritonServer {
        inherit name;
        repo = tritonRepo;
        worldSize = tensorParallelSize;
      };
    };
}
