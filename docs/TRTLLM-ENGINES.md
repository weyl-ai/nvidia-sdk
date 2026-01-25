# TensorRT-LLM Engine Building: A Technical Reference

This document provides comprehensive technical documentation for building TensorRT-LLM engines from HuggingFace models, with specific focus on NVIDIA's pre-quantized NVFP4 models for Blackwell GPUs.

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [The TensorRT-LLM Checkpoint Format](#the-tensorrt-llm-checkpoint-format)
4. [Quantization Formats](#quantization-formats)
5. [Model Conversion Workflows](#model-conversion-workflows)
6. [NVIDIA Pre-Quantized Models](#nvidia-pre-quantized-models)
7. [Nix Integration Challenges](#nix-integration-challenges)
8. [Implementation Strategy](#implementation-strategy)
9. [References](#references)

---

## Executive Summary

TensorRT-LLM is NVIDIA's high-performance inference library for Large Language Models. Deploying a model requires a multi-stage pipeline:

```
HuggingFace Model → TRT-LLM Checkpoint → TensorRT Engine → Triton Server
```

**Key Finding**: NVIDIA's pre-quantized models (e.g., `nvidia/Qwen3-32B-NVFP4`) are distributed in a **Unified HuggingFace Checkpoint** format that can be loaded directly by TensorRT-LLM's Python `LLM` API without explicit checkpoint conversion. However, building standalone TensorRT engines for the native C++ Triton backend requires either:

1. Using the `LLM` API's `save()` method to export the engine
2. Converting to TRT-LLM checkpoint format and using `trtllm-build`

Both approaches require GPU access at build time.

---

## Architecture Overview

### TensorRT-LLM Component Stack

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Deployment Options                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │
│  │  Triton Server  │  │   trtllm-serve  │  │   Direct LLM    │     │
│  │  (C++ Backend)  │  │  (Python/HTTP)  │  │   API (Python)  │     │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘     │
│           │                    │                    │               │
│           └────────────────────┼────────────────────┘               │
│                                │                                     │
│                    ┌───────────▼───────────┐                        │
│                    │   TensorRT Engine     │                        │
│                    │   (.engine files)     │                        │
│                    └───────────┬───────────┘                        │
│                                │                                     │
│           ┌────────────────────┼────────────────────┐               │
│           │                    │                    │               │
│  ┌────────▼────────┐  ┌────────▼────────┐  ┌───────▼────────┐     │
│  │  TRT-LLM        │  │  Unified HF     │  │  HuggingFace   │     │
│  │  Checkpoint     │  │  Checkpoint     │  │  Model         │     │
│  │  (legacy)       │  │  (modelopt)     │  │  (original)    │     │
│  └─────────────────┘  └─────────────────┘  └────────────────┘     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Version Matrix (as of January 2026)

| Component | Version | Notes |
|-----------|---------|-------|
| TensorRT-LLM | 1.1.0 | Current stable release |
| TensorRT | 10.14.1.48 | Required by TRT-LLM 1.1.0 |
| ModelOpt | 0.35.0 | Used for NVIDIA pre-quantized models |
| CUDA | 13.0+ | Required for Blackwell SM120 |

---

## The TensorRT-LLM Checkpoint Format

### Structure

A TRT-LLM checkpoint directory contains:

```
checkpoint/
├── config.json           # Model configuration
├── rank0.safetensors     # Weights for rank 0
├── rank1.safetensors     # Weights for rank 1 (if TP > 1)
└── ...
```

### Config Schema

```json
{
    "architecture": "QWenForCausalLM",
    "dtype": "bfloat16",
    "logits_dtype": "float32",
    "vocab_size": 152064,
    "max_position_embeddings": 131072,
    "hidden_size": 5120,
    "num_hidden_layers": 64,
    "num_attention_heads": 40,
    "num_key_value_heads": 8,
    "hidden_act": "silu",
    "intermediate_size": 27648,
    "norm_epsilon": 1e-6,
    "position_embedding_type": "rope_gpt_neox",
    "mapping": {
        "world_size": 1,
        "tp_size": 1,
        "pp_size": 1
    },
    "quantization": {
        "quant_algo": "NVFP4",
        "kv_cache_quant_algo": "FP8",
        "group_size": 16,
        "exclude_modules": ["lm_head"]
    }
}
```

### Weight Naming Convention

Weights follow a hierarchical naming pattern:

```
transformer.layers.{layer_idx}.{module}.{component}.{tensor_type}
```

Examples:
- `transformer.layers.0.attention.qkv.weight`
- `transformer.layers.0.mlp.fc.weights_scaling_factor`
- `transformer.layers.0.input_layernorm.weight`

---

## Quantization Formats

### NVFP4 (Blackwell-Exclusive)

NVFP4 is a 4-bit floating-point format introduced with NVIDIA Blackwell GPUs:

| Property | Value |
|----------|-------|
| Bits | 4 |
| Format | Floating-point with shared exponent |
| GPU Support | Blackwell (SM 120) only |
| Typical Speedup | 2-4x over FP16 |
| Memory Reduction | ~4x |

**Key Characteristics:**
- Retains floating-point semantics (unlike INT4)
- Higher dynamic range than uniform quantization
- Native Tensor Core support on Blackwell
- Typically paired with FP8 KV cache

### Quantization Config in Pre-Quantized Models

```json
{
    "producer": {
        "name": "modelopt",
        "version": "0.35.0"
    },
    "quantization": {
        "quant_algo": "NVFP4",
        "kv_cache_quant_algo": "FP8",
        "group_size": 16,
        "exclude_modules": ["lm_head"]
    }
}
```

### Supported Quantization Algorithms

| Algorithm | Weight Bits | Activation Bits | GPU Requirement |
|-----------|-------------|-----------------|-----------------|
| FP16/BF16 | 16 | 16 | Any CUDA |
| FP8 | 8 | 8 | Hopper+, Ada+ |
| INT8_SQ | 8 | 8 | Ampere+ |
| INT4_AWQ | 4 | 16 | Any CUDA |
| W4A8_AWQ | 4 | 8 | Hopper+ |
| NVFP4 | 4 | 4 | Blackwell only |

---

## Model Conversion Workflows

### Workflow 1: Standard HuggingFace Model

For non-quantized HuggingFace models:

```bash
# Step 1: Convert HF checkpoint to TRT-LLM checkpoint
python convert_checkpoint.py \
    --model_dir /path/to/hf/model \
    --output_dir /path/to/trtllm/checkpoint \
    --dtype bfloat16 \
    --tp_size 1

# Step 2: Build TensorRT engine
trtllm-build \
    --checkpoint_dir /path/to/trtllm/checkpoint \
    --output_dir /path/to/engine \
    --gemm_plugin bfloat16 \
    --max_batch_size 8 \
    --max_input_len 8192 \
    --max_seq_len 16384 \
    --paged_kv_cache enable \
    --use_paged_context_fmha enable
```

### Workflow 2: Quantize with ModelOpt then Convert

For custom quantization:

```bash
# Step 1: Quantize with ModelOpt
python hf_ptq.py \
    --pyt_ckpt_path /path/to/hf/model \
    --qformat nvfp4 \
    --export_path /path/to/quantized/checkpoint

# Step 2: Build engine (unified checkpoint can be used directly)
# With TRT-LLM LLM API:
python -c "
from tensorrt_llm import LLM
llm = LLM(model='/path/to/quantized/checkpoint')
llm.save('/path/to/engine')
"
```

### Workflow 3: NVIDIA Pre-Quantized Models (Unified Checkpoint)

For models like `nvidia/Qwen3-32B-NVFP4`:

```python
from tensorrt_llm import LLM, SamplingParams

# Load directly - auto-builds engine on first run
llm = LLM(model="nvidia/Qwen3-32B-NVFP4")

# Generate
outputs = llm.generate(["Hello"], SamplingParams(max_tokens=100))

# Save engine for later use
llm.save("/path/to/engine")
```

**Critical Insight**: The unified checkpoint format means the model weights are already in a TRT-LLM-compatible layout. The `LLM` class handles:
1. Loading the quantized weights
2. Building the TensorRT engine (cached)
3. Running inference

---

## NVIDIA Pre-Quantized Models

### Available Models (nvidia/*)

| Model | Size | Quantization | KV Cache | GPU Requirement |
|-------|------|--------------|----------|-----------------|
| nvidia/Qwen3-32B-NVFP4 | ~17GB | NVFP4 | FP8 | Blackwell |
| nvidia/Qwen3-32B-FP8 | ~32GB | FP8 | FP8 | Hopper+ |
| nvidia/Llama-3.1-8B-FP8 | ~8GB | FP8 | FP8 | Hopper+ |
| nvidia/Phi-4-NVFP4 | ~7GB | NVFP4 | FP8 | Blackwell |

### Model Card: nvidia/Qwen3-32B-NVFP4

**Source**: https://huggingface.co/nvidia/Qwen3-32B-NVFP4

```yaml
Architecture: Qwen3-32B (Transformer)
Parameters: 32.8B (original), ~17B (quantized storage)
Quantization:
  Algorithm: NVFP4
  KV Cache: FP8
  Group Size: 16
  Excluded: lm_head
Producer: modelopt v0.35.0
Context Length: 131K tokens
License: Apache 2.0
Hardware: Blackwell GPUs only (SM 120)
```

**Benchmark Results (B200)**:

| Metric | BF16 | NVFP4 |
|--------|------|-------|
| MMLU Pro | 0.80 | 0.78 |
| MATH-500 | 0.96 | 0.96 |
| AIME 2024 | 0.81 | 0.80 |

### File Structure

```
nvidia/Qwen3-32B-NVFP4/
├── config.json              # HuggingFace model config
├── generation_config.json   # Generation parameters
├── hf_quant_config.json     # ModelOpt quantization config
├── tokenizer.json           # Tokenizer
├── tokenizer_config.json
├── special_tokens_map.json
├── merges.txt
├── vocab.json
├── model-00001-of-00005.safetensors  # Quantized weights
├── model-00002-of-00005.safetensors
├── model-00003-of-00005.safetensors
├── model-00004-of-00005.safetensors
├── model-00005-of-00005.safetensors
└── model.safetensors.index.json
```

---

## Nix Integration Challenges

### The Fundamental Problem

Nix builds are **sandboxed** and **reproducible**. TensorRT engine building requires:

1. **GPU Access**: TensorRT compiles kernels optimized for specific GPU architectures
2. **CUDA Runtime**: Actual GPU memory allocation and kernel compilation
3. **Network Access**: For downloading models (can be solved with FOD)

This creates a fundamental tension:
- Nix sandbox prevents GPU access
- Engine building requires GPU
- `__noChroot = true` breaks reproducibility guarantees

### Attempted Solutions

#### Solution 1: `__noChroot = true` (Current Approach)

```nix
stdenv.mkDerivation {
  # ...
  __noChroot = true;  # Disable sandbox
  buildCommand = ''
    # Can access GPU but breaks reproducibility
    python -c "
      from tensorrt_llm import LLM
      llm = LLM(model='nvidia/Qwen3-32B-NVFP4')
      llm.save('$out')
    "
  '';
}
```

**Problem**: The Python `LLM` API has internal dependencies that try to write to `$HOME`:
- `flashinfer` creates workspace directories
- HuggingFace cache
- Various temporary files

**Error observed**:
```
PermissionError: [Errno 13] Permission denied: '/homeless-shelter'
```

#### Solution 2: Environment Variable Fixes

```nix
buildCommand = ''
  export HOME="$TMPDIR/home"
  export HF_HOME="$TMPDIR/hf_cache"
  export FLASHINFER_WORKSPACE_DIR="$TMPDIR/flashinfer"
  mkdir -p "$HOME" "$HF_HOME" "$FLASHINFER_WORKSPACE_DIR"
  # ... build commands
'';
```

**Status**: Partially addresses the issue but other internal paths may still fail.

#### Solution 3: Pre-download Model as FOD

```nix
qwen3-hf-model = stdenvNoCC.mkDerivation {
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = "sha256-Uekvo4NlzbrbZcKPSyzd7opvZDh+JOE55jrUbcsMu8Q=";
  
  buildCommand = ''
    git lfs install
    git clone https://huggingface.co/nvidia/Qwen3-32B-NVFP4 $out
    rm -rf $out/.git
  '';
};
```

**Status**: Works for model download, but engine building still needs GPU.

### Recommended Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    Nix Build Pipeline                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────┐                                             │
│  │  mkHfModel      │  Pure FOD - downloads HF model              │
│  │  (sandboxed)    │  Hash: sha256-Uekvo4NlzbrbZcKPSyzd7o...     │
│  └────────┬────────┘                                             │
│           │                                                       │
│           ▼                                                       │
│  ┌─────────────────┐                                             │
│  │  mkEngine       │  Impure - requires GPU access               │
│  │  (__noChroot)   │  Builds TensorRT engine                     │
│  └────────┬────────┘                                             │
│           │                                                       │
│           ▼                                                       │
│  ┌─────────────────┐                                             │
│  │  mkTritonRepo   │  Pure - generates config files              │
│  │  (sandboxed)    │  Links to engine output                     │
│  └────────┬────────┘                                             │
│           │                                                       │
│           ▼                                                       │
│  ┌─────────────────┐                                             │
│  │  mkTritonServer │  Pure - shell wrapper script                │
│  │  (sandboxed)    │  Sets up environment                        │
│  └─────────────────┘                                             │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## Implementation Strategy

### Option A: Use trtllm-build with convert_checkpoint.py

The canonical approach requires the `convert_checkpoint.py` script from TRT-LLM examples:

```bash
# 1. Download the script
git clone --depth 1 https://github.com/NVIDIA/TensorRT-LLM
cd TensorRT-LLM/examples/qwen

# 2. Convert checkpoint
python convert_checkpoint.py \
    --model_dir /path/to/nvidia/Qwen3-32B-NVFP4 \
    --output_dir /path/to/trtllm_checkpoint \
    --dtype bfloat16

# 3. Build engine
trtllm-build \
    --checkpoint_dir /path/to/trtllm_checkpoint \
    --output_dir /path/to/engine \
    --gemm_plugin nvfp4 \
    --max_batch_size 8 \
    --paged_kv_cache enable
```

**Nix Implementation**:
```nix
mkCheckpoint = { hfModel, ... }: stdenv.mkDerivation {
  __noChroot = true;
  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "TensorRT-LLM";
    # pin to specific version
  };
  buildCommand = ''
    cd examples/qwen
    python convert_checkpoint.py \
      --model_dir ${hfModel} \
      --output_dir $out \
      --dtype bfloat16
  '';
};
```

### Option B: Use LLM API with Proper Environment

```nix
mkEngine = { model, ... }: stdenv.mkDerivation {
  __noChroot = true;
  buildCommand = ''
    export HOME="$TMPDIR/home"
    export HF_HOME="$TMPDIR/hf"
    export FLASHINFER_WORKSPACE_DIR="$TMPDIR/flashinfer"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    export TORCH_HOME="$TMPDIR/torch"
    mkdir -p "$HOME" "$HF_HOME" "$FLASHINFER_WORKSPACE_DIR" "$XDG_CACHE_HOME" "$TORCH_HOME"
    
    python << 'EOF'
    from tensorrt_llm import LLM, BuildConfig
    
    build_config = BuildConfig(
        max_batch_size=8,
        max_input_len=8192,
        max_seq_len=16384,
    )
    
    llm = LLM(
        model="${model}",
        build_config=build_config,
    )
    
    import os
    llm.save(os.environ['out'])
    EOF
  '';
};
```

### Option C: Runtime Engine Building (Current trtllm-runner.nix)

Build engines at first runtime instead of build time:

```nix
# Engines cached at ~/.cache/tensorrt_llm/
mkRunner = { model, ... }: writeShellApplication {
  text = ''
    python -c "
      from tensorrt_llm import LLM
      llm = LLM(model='${model}')
      # Engine auto-built and cached
      llm.generate(['Hello'])
    "
  '';
};
```

**Trade-offs**:
| Aspect | Build-time Engine | Runtime Engine |
|--------|-------------------|----------------|
| First-run latency | Fast | Slow (builds engine) |
| Reproducibility | Partial (impure build) | None |
| Cacheability | Nix store | User cache |
| GPU requirement | Build machine | Runtime machine |

---

## References

### Official Documentation

1. **TensorRT-LLM Documentation**
   - Checkpoint Format: https://nvidia.github.io/TensorRT-LLM/architecture/checkpoint.html
   - trtllm-build: https://nvidia.github.io/TensorRT-LLM/commands/trtllm-build.html
   - Workflow: https://nvidia.github.io/TensorRT-LLM/architecture/workflow.html

2. **TensorRT Model Optimizer (ModelOpt)**
   - PTQ Guide: https://github.com/NVIDIA/TensorRT-Model-Optimizer/blob/main/examples/llm_ptq/README.md
   - Unified Checkpoint: https://nvidia.github.io/TensorRT-Model-Optimizer/deployment/3_unified_hf.html

3. **NVIDIA Pre-Quantized Models**
   - Collection: https://huggingface.co/collections/nvidia/inference-optimized-checkpoints-with-model-optimizer
   - Qwen3-32B-NVFP4: https://huggingface.co/nvidia/Qwen3-32B-NVFP4

### Key Code Repositories

1. **TensorRT-LLM**: https://github.com/NVIDIA/TensorRT-LLM
   - `examples/qwen/convert_checkpoint.py` - Qwen conversion script
   - `tensorrt_llm/models/qwen/` - Qwen model implementation

2. **TensorRT-Model-Optimizer**: https://github.com/NVIDIA/TensorRT-Model-Optimizer
   - `examples/llm_ptq/hf_ptq.py` - HuggingFace PTQ script
   - `modelopt/torch/export/` - Export APIs

### Related Issues and Discussions

1. **Loading pre-quantized models**: https://github.com/NVIDIA/TensorRT-LLM/issues/2458
2. **NVFP4 serving issues**: https://github.com/NVIDIA/TensorRT-Model-Optimizer/issues/187

---

## Appendix: Quick Reference

### trtllm-build Common Options

```bash
trtllm-build \
  --checkpoint_dir <path>           # TRT-LLM checkpoint directory
  --output_dir <path>               # Output engine directory
  --gemm_plugin <dtype>             # auto|float16|bfloat16|fp8|nvfp4
  --max_batch_size <int>            # Maximum batch size
  --max_input_len <int>             # Maximum input sequence length
  --max_seq_len <int>               # Maximum total sequence length
  --max_num_tokens <int>            # Maximum tokens per batch
  --paged_kv_cache enable           # Enable paged KV cache
  --use_paged_context_fmha enable   # Enable paged context FMHA
  --use_fp8_context_fmha enable     # Enable FP8 context FMHA
  --workers <int>                   # Parallel build workers
```

### Environment Variables

```bash
# TensorRT-LLM
export TLLM_LOG_LEVEL=WARNING

# HuggingFace
export HF_HOME=/path/to/cache
export HF_TOKEN=<token>

# CUDA
export CUDA_HOME=/path/to/cuda
export LD_LIBRARY_PATH=/run/opengl-driver/lib:$LD_LIBRARY_PATH

# Flashinfer (internal TRT-LLM dependency)
export FLASHINFER_WORKSPACE_DIR=/path/to/workspace

# General
export HOME=/path/to/writable/dir
```

### Model Architecture Mapping

| HuggingFace Architecture | TRT-LLM Model | convert_checkpoint.py Location |
|--------------------------|---------------|-------------------------------|
| Qwen2ForCausalLM | QWenForCausalLM | examples/qwen/ |
| Qwen3ForCausalLM | QWenForCausalLM | examples/qwen/ |
| LlamaForCausalLM | LLaMAForCausalLM | examples/llama/ |
| PhiForCausalLM | PhiForCausalLM | examples/phi/ |
| MixtralForCausalLM | MixtralForCausalLM | examples/mixtral/ |
