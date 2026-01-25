# TensorRT-LLM Engine Builder
# 
# Provides derivations for building TRT-LLM engines and Triton model repositories.
# These are IMPURE builds that require GPU access (__noChroot = true).
#
# Usage:
#   engines = callPackage ./trtllm-engine.nix { };
#   qwen3-engine = engines.mkEngine { 
#     name = "qwen3-32b-nvfp4";
#     model = "nvidia/Qwen3-32B-NVFP4";
#   };
#   qwen3-triton = engines.mkTritonRepo {
#     name = "qwen3-32b";
#     engine = qwen3-engine;
#   };

{
  lib,
  stdenvNoCC,
  stdenv,
  runCommand,
  writeTextFile,
  writeShellApplication,
  fetchurl,
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

  # Environment setup for TRT-LLM commands
  envSetup = ''
    export PYTHONPATH="${triton}/python''${PYTHONPATH:+:$PYTHONPATH}"
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:${triton}/lib:${triton}/tensorrt_llm/lib:${cuda}/lib64:${openmpi}/lib:${python}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export CUDA_HOME="${cuda}"
    export HOME="$TMPDIR/home"
    export HF_HOME="$TMPDIR/hf_cache"
    export TLLM_LOG_LEVEL="WARNING"
    export FLASHINFER_WORKSPACE_DIR="$TMPDIR/flashinfer"
    mkdir -p "$HOME" "$HF_HOME" "$FLASHINFER_WORKSPACE_DIR"
  '';

in
{
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
  # mkCheckpoint: Convert HuggingFace model to TRT-LLM checkpoint format
  # ============================================================================
  # NOTE: This is an IMPURE build that requires GPU access for quantized models
  mkCheckpoint =
    {
      name,           # e.g. "qwen3-32b-nvfp4"
      hfModel,        # Output of mkHfModel
      modelType ? "qwen",  # Model architecture: qwen, llama, phi, etc.
      dtype ? "bfloat16",
      tensorParallelSize ? 1,
      pipelineParallelSize ? 1,
      extraArgs ? "",
    }:
    stdenv.mkDerivation {
      pname = "trtllm-checkpoint-${name}";
      version = "1.0.0";

      # IMPURE: requires GPU for quantized model conversion
      __noChroot = true;

      nativeBuildInputs = [ python openmpi ];

      buildCommand = ''
        ${envSetup}

        echo "Converting ${name} to TRT-LLM checkpoint format..."
        echo "Model type: ${modelType}"
        echo "Source: ${hfModel}"
        
        mkdir -p $out

        # Use TRT-LLM's convert module
        ${python}/bin/python -c "
import sys
sys.path.insert(0, '${triton}/python')

from tensorrt_llm.models.${modelType}.convert import convert_hf_config, convert_hf_weights
from tensorrt_llm.models.${modelType}.config import ${lib.toUpper (builtins.substring 0 1 modelType)}${builtins.substring 1 (-1) modelType}Config
from tensorrt_llm.mapping import Mapping
import json
import os

hf_model_dir = '${hfModel}'
output_dir = '$out'
dtype = '${dtype}'
tp_size = ${toString tensorParallelSize}
pp_size = ${toString pipelineParallelSize}

print(f'Loading config from {hf_model_dir}')
config = convert_hf_config(hf_model_dir, dtype=dtype, mapping=Mapping(world_size=tp_size*pp_size, tp_size=tp_size, pp_size=pp_size))

print(f'Saving config to {output_dir}')
with open(os.path.join(output_dir, 'config.json'), 'w') as f:
    json.dump(config.to_dict(), f, indent=2)

print('Converting weights...')
convert_hf_weights(hf_model_dir, output_dir, config)

print('Checkpoint conversion complete')
" ${extraArgs}

        echo "Checkpoint saved to $out"
      '';

      meta = {
        description = "TRT-LLM checkpoint for ${name}";
      };
    };

  # ============================================================================
  # mkEngine: Build TensorRT engine from checkpoint
  # ============================================================================
  # NOTE: This is an IMPURE build that requires GPU access
  mkEngine =
    {
      name,           # e.g. "qwen3-32b-nvfp4"
      checkpoint,     # Output of mkCheckpoint, or path to HF model for unified models
      maxBatchSize ? 8,
      maxInputLen ? 8192,
      maxSeqLen ? 16384,
      maxNumTokens ? 8192,
      gemmPlugin ? "bfloat16",
      extraArgs ? "",
    }:
    stdenv.mkDerivation {
      pname = "trtllm-engine-${name}";
      version = "1.0.0";

      # IMPURE: requires GPU for TensorRT engine compilation
      __noChroot = true;

      nativeBuildInputs = [ python openmpi ];

      buildCommand = ''
        ${envSetup}

        echo "Building TensorRT engine for ${name}..."
        echo "Checkpoint: ${checkpoint}"
        
        mkdir -p $out

        ${python}/bin/python -m tensorrt_llm.commands.build \
          --checkpoint_dir "${checkpoint}" \
          --output_dir "$out" \
          --gemm_plugin ${gemmPlugin} \
          --max_batch_size ${toString maxBatchSize} \
          --max_input_len ${toString maxInputLen} \
          --max_seq_len ${toString maxSeqLen} \
          --max_num_tokens ${toString maxNumTokens} \
          --paged_kv_cache enable \
          --use_paged_context_fmha enable \
          ${extraArgs}

        echo "Engine saved to $out"
        ls -la $out/
      '';

      meta = {
        description = "TensorRT-LLM engine for ${name}";
      };
    };

  # ============================================================================
  # mkEngineFromHf: Build engine directly from HuggingFace model (for NVFP4 models)
  # ============================================================================
  # For pre-quantized models like nvidia/Qwen3-32B-NVFP4, TRT-LLM can build
  # the engine directly without separate checkpoint conversion
  mkEngineFromHf =
    {
      name,           # e.g. "qwen3-32b-nvfp4"
      model,          # HuggingFace model ID or local path
      maxBatchSize ? 8,
      maxInputLen ? 8192,
      maxSeqLen ? 16384,
      maxNumTokens ? 8192,
      tensorParallelSize ? 1,
      extraBuildArgs ? "",
    }:
    stdenv.mkDerivation {
      pname = "trtllm-engine-${name}";
      version = "1.0.0";

      # IMPURE: requires GPU for TensorRT engine compilation
      __noChroot = true;

      nativeBuildInputs = [ python openmpi cacert ];

      SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

      buildCommand = ''
        ${envSetup}

        echo "Building TensorRT engine for ${name} from ${model}..."
        
        mkdir -p $out

        # Create Python build script
        cat > $TMPDIR/build_engine.py << 'PYTHON_EOF'
import os
import sys

# Ensure environment is set
os.environ.setdefault('HF_HOME', os.environ.get('HF_HOME', '/tmp/hf_cache'))
os.environ.setdefault('TLLM_LOG_LEVEL', 'WARNING')

from tensorrt_llm import LLM, BuildConfig

model_path = "${model}"
output_dir = os.environ['out']
tp_size = ${toString tensorParallelSize}

print(f"Building TensorRT engine...")
print(f"  Model: {model_path}")
print(f"  Output: {output_dir}")
print(f"  Tensor parallel size: {tp_size}")

build_config = BuildConfig(
    max_batch_size=${toString maxBatchSize},
    max_input_len=${toString maxInputLen},
    max_seq_len=${toString maxSeqLen},
    max_num_tokens=${toString maxNumTokens},
)

llm = LLM(
    model=model_path,
    tensor_parallel_size=tp_size,
    build_config=build_config,
)

print(f"Saving engine to {output_dir}")
llm.save(output_dir)

print("Engine build complete")
print("Contents:", os.listdir(output_dir))
PYTHON_EOF

        # TRT-LLM requires MPI even for single-GPU operations
        ${openmpi}/bin/mpirun \
          -np ${toString tensorParallelSize} \
          --oversubscribe \
          --allow-run-as-root \
          -x LD_LIBRARY_PATH \
          -x PYTHONPATH \
          -x CUDA_HOME \
          -x HOME \
          -x HF_HOME \
          -x TLLM_LOG_LEVEL \
          -x FLASHINFER_WORKSPACE_DIR \
          -x out \
          ${python}/bin/python $TMPDIR/build_engine.py
      '';

      meta = {
        description = "TensorRT-LLM engine for ${name}";
      };
    };

  # ============================================================================
  # mkTritonRepo: Generate Triton model repository with native tensorrtllm backend
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
      # Triton config.pbtxt for tensorrtllm backend
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
            {
              name: "input_ids"
              data_type: TYPE_INT32
              dims: [ -1 ]
            },
            {
              name: "input_lengths"
              data_type: TYPE_INT32
              dims: [ 1 ]
              reshape: { shape: [ ] }
            },
            {
              name: "request_output_len"
              data_type: TYPE_INT32
              dims: [ 1 ]
              reshape: { shape: [ ] }
            },
            {
              name: "end_id"
              data_type: TYPE_INT32
              dims: [ 1 ]
              reshape: { shape: [ ] }
              optional: true
            },
            {
              name: "pad_id"
              data_type: TYPE_INT32
              dims: [ 1 ]
              reshape: { shape: [ ] }
              optional: true
            },
            {
              name: "streaming"
              data_type: TYPE_BOOL
              dims: [ 1 ]
              reshape: { shape: [ ] }
              optional: true
            },
            {
              name: "temperature"
              data_type: TYPE_FP32
              dims: [ 1 ]
              reshape: { shape: [ ] }
              optional: true
            },
            {
              name: "top_p"
              data_type: TYPE_FP32
              dims: [ 1 ]
              reshape: { shape: [ ] }
              optional: true
            },
            {
              name: "top_k"
              data_type: TYPE_INT32
              dims: [ 1 ]
              reshape: { shape: [ ] }
              optional: true
            }
          ]

          output [
            {
              name: "output_ids"
              data_type: TYPE_INT32
              dims: [ -1, -1 ]
            },
            {
              name: "sequence_length"
              data_type: TYPE_INT32
              dims: [ -1 ]
            },
            {
              name: "cum_log_probs"
              data_type: TYPE_FP32
              dims: [ -1 ]
            },
            {
              name: "output_log_probs"
              data_type: TYPE_FP32
              dims: [ -1, -1 ]
            }
          ]

          instance_group [
            {
              count: 1
              kind: KIND_CPU
            }
          ]

          parameters: {
            key: "gpt_model_type"
            value: {
              string_value: "inflight_fused_batching"
            }
          }
          parameters: {
            key: "gpt_model_path"
            value: {
              string_value: "ENGINE_PATH_PLACEHOLDER"
            }
          }
          parameters: {
            key: "batch_scheduler_policy"
            value: {
              string_value: "${batchSchedulerPolicy}"
            }
          }
          parameters: {
            key: "kv_cache_free_gpu_mem_fraction"
            value: {
              string_value: "${toString kvCacheFreeGpuMemFraction}"
            }
          }
          ${lib.optionalString enableChunkedContext ''
          parameters: {
            key: "enable_chunked_context"
            value: {
              string_value: "true"
            }
          }
          ''}
          parameters: {
            key: "decoding_mode"
            value: {
              string_value: "${decodingMode}"
            }
          }
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
    }:
    writeShellApplication {
      name = "tritonserver-${name}";
      runtimeInputs = [ triton openmpi ];
      text = ''
        export LD_LIBRARY_PATH="/run/opengl-driver/lib:${triton}/lib:${triton}/tensorrt_llm/lib:${cuda}/lib64:${openmpi}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

        exec ${triton}/bin/tritonserver \
          --model-repository=${repo} \
          --http-port=${toString httpPort} \
          --grpc-port=${toString grpcPort} \
          --metrics-port=${toString metricsPort} \
          "$@"
      '';
      meta = {
        description = "Triton Inference Server for ${name}";
        mainProgram = "tritonserver-${name}";
      };
    };
}
