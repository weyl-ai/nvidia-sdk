# TensorRT-LLM Engine Building

Build TensorRT-LLM engines for NVIDIA's pre-quantized NVFP4 models.

## Quick Start

```bash
# Build Qwen3-32B-NVFP4 engine (requires GPU, ~10 minutes)
nix build .#qwen3-32b-engine --option sandbox false

# Point symlink to built engine
ln -sf $(nix build .#qwen3-32b-engine --print-out-paths --option sandbox false) ~/.cache/trtllm-engines/qwen3

# Start Triton server (single GPU)
nix run .#tritonserver-qwen3

# Start OpenAI-compatible proxy
nix run .#openai-qwen3

# Test
curl http://localhost:9000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3","messages":[{"role":"user","content":"Hello"}],"max_tokens":50}'
```

## What Works

### Single-GPU (TP=1)
- **Build**: `nix build .#qwen3-32b-engine --option sandbox false`
- **Serve**: `nix run .#tritonserver-qwen3`
- **OpenAI API**: `nix run .#openai-qwen3` → `http://localhost:9000/v1`
- Uses `trtllm-bench build` with timeout to work around MPI hang

### Multi-GPU (TP=4)
- **Build**: `nix build .#qwen3-32b-engine-tp4 --option sandbox false`
- **Serve**: `nix run .#tritonserver-qwen3-tp4`
- **OpenAI API**: Same `nix run .#openai-qwen3` (connects to Triton gRPC)
- Uses checkpoint conversion + `trtllm-build --workers 4`

### OpenWebUI Integration
1. Start Triton: `nix run .#tritonserver-qwen3-tp4`
2. Start OpenAI proxy: `nix run .#openai-qwen3`
3. Configure OpenWebUI:
   - **Base URL**: `http://localhost:9000/v1`
   - **API Key**: `sk-dummy` (anything works)
4. Select model `qwen3` in chat

### Streaming
- HTTP SSE streaming works via OpenAI proxy
- gRPC streaming works via `tritonclient.grpc.aio` with `stream_infer()`
- Headers set for proper streaming through reverse proxies:
  - `X-Accel-Buffering: no`
  - `Cache-Control: no-cache`

## What Doesn't Work / Gotchas

### MPI Hang on Shutdown
TensorRT-LLM's `LLM` Python API hangs during shutdown due to `MpiPoolSession` spawning workers that never complete. **Solution**: Use `timeout` to kill the process after engine is saved.

### Multi-GPU Build: Wrong Quantization
The `from_hugging_face()` method needs explicit `quant_config` for pre-quantized NVFP4 models. Without it, the engine builds as unquantized bf16 (16GB per rank instead of 6GB) and produces garbage output.

**Fixed in**: `d24b633` - now reads `hf_quant_config.json` and passes proper `QuantConfig`.

### Config.json Overwrite
When copying tokenizer files, don't copy the HuggingFace model's `config.json` - it overwrites the TRT-LLM engine config and causes `key 'builder_config' not found` errors.

**Fixed in**: Explicitly copy only tokenizer files, not `*.json`.

### gRPC Decoupled Mode
TensorRT-LLM backend uses decoupled transaction policy for streaming. Regular `client.infer()` fails with `ModelInfer RPC doesn't support models with decoupled transaction policy`.

**Solution**: Use async streaming:
```python
import tritonclient.grpc.aio as grpcclient

async for response in client.stream_infer(inputs_iterator=request_gen()):
    result, error = response
    # process result
```

### Buffering Through Proxies
SSE streams may buffer through nginx/tailscale. **Solution**: Set response headers:
```python
headers={
    "Cache-Control": "no-cache",
    "X-Accel-Buffering": "no",
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         OpenWebUI                                │
│                    http://localhost:8080                         │
└─────────────────────────┬───────────────────────────────────────┘
                          │ HTTP (OpenAI API)
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OpenAI Proxy (FastAPI)                        │
│                    http://localhost:9000/v1                      │
│  - Chat template application                                     │
│  - Tokenization (transformers)                                   │
│  - SSE streaming                                                 │
└─────────────────────────┬───────────────────────────────────────┘
                          │ gRPC (streaming)
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Triton Inference Server                       │
│              HTTP :8000 / gRPC :8001 / Metrics :8002            │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │preprocessing │→ │ tensorrt_llm │→ │   postprocessing     │   │
│  │  (Python)    │  │  (TRT-LLM)   │  │      (Python)        │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
│                           │                                      │
│                    ┌──────┴──────┐                               │
│                    │  ensemble   │ ← /v2/models/ensemble/generate│
│                    └─────────────┘                               │
└─────────────────────────┬───────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
    ┌─────────┐     ┌─────────┐     ┌─────────┐
    │  GPU 0  │     │  GPU 1  │     │  GPU 2  │  ...
    │ rank0   │     │ rank1   │     │ rank2   │
    └─────────┘     └─────────┘     └─────────┘
```

## Build Details

### Single GPU (trtllm-bench)

```bash
timeout 900 mpirun -np 1 --allow-run-as-root \
  python -m tensorrt_llm.commands.bench \
    --model nvidia/Qwen3-32B-NVFP4 \
    --workspace /tmp \
    build \
    --quantization NVFP4 \
    --max_batch_size 8 \
    --max_num_tokens 8192 \
    --max_seq_len 16384 \
    --tp_size 1
```

Engine saved before MPI hang; timeout kills stuck process.

### Multi-GPU (checkpoint + trtllm-build)

Three-step process:

1. **Download model**:
```python
from huggingface_hub import snapshot_download
snapshot_download("nvidia/Qwen3-32B-NVFP4", local_dir=model_dir)
```

2. **Convert to TRT-LLM checkpoint** (for each rank):
```python
from tensorrt_llm.models import QWenForCausalLM
from tensorrt_llm.models.modeling_utils import QuantConfig
from tensorrt_llm.quantization import QuantAlgo

quant_config = QuantConfig(
    quant_algo=QuantAlgo.NVFP4,
    kv_cache_quant_algo=QuantAlgo.FP8,
    group_size=16,
)

for rank in range(world_size):
    mapping = Mapping(world_size=world_size, rank=rank, tp_size=tp_size)
    model = QWenForCausalLM.from_hugging_face(
        model_dir, mapping=mapping, quant_config=quant_config
    )
    model.save_checkpoint(checkpoint_dir)
```

3. **Build engine**:
```bash
python -m tensorrt_llm.commands.build \
  --checkpoint_dir checkpoint \
  --output_dir engine \
  --workers 4 \
  --paged_kv_cache enable \
  --use_paged_context_fmha enable
```

## Engine Files

### Single GPU (~20GB total)
```
rank0.engine          # 20GB - full model
config.json           # TRT-LLM engine config
tokenizer.json        # Tokenizer files
...
```

### 4-GPU (~6GB per rank, ~24GB total)
```
rank0.engine          # 6GB - sharded
rank1.engine
rank2.engine
rank3.engine
config.json           # Shows tp_size=4, quant_algo=NVFP4
tokenizer.json
...
```

## Available Packages

| Package | GPUs | VRAM/GPU | Batch | Context | Build Time |
|---------|------|----------|-------|---------|------------|
| `qwen3-32b-engine` | 1 | ~24GB | 8 | 16K | ~10 min |
| `qwen3-32b-engine-tp2` | 2 | ~12GB | 16 | 24K | ~15 min |
| `qwen3-32b-engine-tp4` | 4 | ~7GB | 32 | 32K | ~20 min |

Triton servers:
- `tritonserver-qwen3` - Single GPU
- `tritonserver-qwen3-tp2` - 2 GPU
- `tritonserver-qwen3-tp4` - 4 GPU

OpenAI proxy:
- `openai-qwen3` - Connects to any Triton on localhost:8001

## NCCL Configuration (PCIe)

For PCIe topology without NVLink:

```bash
NCCL_IB_DISABLE=1          # No InfiniBand
NCCL_P2P_LEVEL=PHB         # PCIe peer-to-peer via host bridge
NCCL_SHM_DISABLE=0         # Enable shared memory
```

## Endpoints

| Service | Port | Protocol | Use |
|---------|------|----------|-----|
| Triton HTTP | 8000 | HTTP | Health, generate API |
| Triton gRPC | 8001 | gRPC | Streaming inference |
| Triton Metrics | 8002 | HTTP | Prometheus metrics |
| OpenAI Proxy | 9000 | HTTP | OpenAI-compatible API |

### Test Commands

```bash
# Triton HTTP
curl localhost:8000/v2/health/ready

# Triton generate
curl localhost:8000/v2/models/ensemble/generate \
  -d '{"text_input":"<|im_start|>user\nHello<|im_end|>\n<|im_start|>assistant\n","max_tokens":50}'

# OpenAI (non-streaming)
curl localhost:9000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3","messages":[{"role":"user","content":"Hello"}],"max_tokens":50}'

# OpenAI (streaming)
curl -N localhost:9000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3","messages":[{"role":"user","content":"Hello"}],"max_tokens":50,"stream":true}'
```

## Troubleshooting

### Garbage output (repeating tokens like "unounouno")
Engine was built without NVFP4 quantization. Check `config.json`:
```bash
cat ~/.cache/trtllm-engines/qwen3-tp4/config.json | jq '.pretrained_config.quantization'
```
Should show `"quant_algo": "NVFP4"`. If null, rebuild with fixed `trtllm-engine.nix`.

### "key 'builder_config' not found"
HuggingFace `config.json` overwrote engine config. Rebuild - the fix ensures only tokenizer files are copied.

### Engine size wrong (16GB vs 6GB per rank)
Same as garbage output - quantization not applied. Rebuild.

### gRPC "decoupled transaction policy" error
Use streaming API, not regular `infer()`:
```python
async for response in client.stream_infer(inputs_iterator=...):
```

### Streaming buffers through proxy
Ensure `X-Accel-Buffering: no` header is set. Fixed in `openai-proxy.nix`.

### Build hangs forever
Normal - the 900s timeout kills it. Engine is saved before hang. Check for `rank0.engine` in build dir.

### Multi-GPU: "MPI size mismatch"
Ensure `worldSize` in Triton server matches `tensorParallelSize` in engine build.
