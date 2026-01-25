# TensorRT-LLM Engine Building

Build TensorRT-LLM engines for NVIDIA's pre-quantized NVFP4 models.

## Quick Start

```bash
# Build Qwen3-32B-NVFP4 engine (requires GPU, ~10 minutes)
nix build .#qwen3-32b-engine --option sandbox false

# Point symlink to built engine
ln -sf /nix/store/<hash>-trtllm-engine-qwen3-32b-nvfp4-1.0.0 ~/.cache/trtllm-engines/qwen3

# Start Triton server
nix run .#tritonserver-qwen3

# Start OpenAI-compatible proxy
nix run .#openai-qwen3

# Test
curl http://localhost:9000/v1/chat/completions \
  -d '{"model":"qwen3","messages":[{"role":"user","content":"Hello"}],"max_tokens":50}'
```

## How It Works

### The Problem

TensorRT-LLM's `LLM` Python API builds engines but hangs during shutdown due to MPI worker spawning in `MpiPoolSession`. The `llm.shutdown()` method triggers MPI subprocess creation that never completes when run under `mpirun -np 1`.

### The Solution

Use `trtllm-bench build` with a timeout:

```bash
timeout 600 mpirun -np 1 --allow-run-as-root \
  python -m tensorrt_llm.commands.bench \
    --model nvidia/Qwen3-32B-NVFP4 \
    --workspace /tmp \
    build \
    --quantization NVFP4 \
    --max_batch_size 8 \
    --max_num_tokens 8192 \
    --max_seq_len 16384 \
    --tp_size 1 \
    --trust_remote_code True
```

The engine is saved to `$workspace/tmp*-llm-workspace/tmp.engine/` before the hang occurs. The timeout kills the hung process, and we copy the engine files.

### Nix Implementation

`nix/trtllm-engine.nix` provides `mkEngine`:

```nix
qwen3-32b-engine = engines.mkEngine {
  name = "qwen3-32b-nvfp4";
  hfModel = "nvidia/Qwen3-32B-NVFP4";  # HuggingFace model ID
  quantization = "NVFP4";
  tensorParallelSize = 1;
  maxBatchSize = 8;
  maxSeqLen = 16384;
  maxNumTokens = 8192;
};
```

Key details:
- `__noChroot = true` - impure build requiring GPU access
- Downloads model from HuggingFace during build
- Engine output: `rank0.engine` (~20GB) + tokenizer files
- Build time: ~5-10 minutes on Blackwell

## Engine Files

A built engine contains:

```
/nix/store/<hash>-trtllm-engine-qwen3-32b-nvfp4-1.0.0/
├── config.json           # TRT-LLM engine config
├── rank0.engine          # TensorRT engine (~20GB)
├── tokenizer.json        # Tokenizer
├── tokenizer_config.json
├── vocab.json
├── merges.txt
├── added_tokens.json
├── special_tokens_map.json
└── chat_template.jinja
```

## Testing the Engine

```bash
export LD_LIBRARY_PATH="/run/opengl-driver/lib"
export PYTHONPATH="$(nix build .#tritonserver-trtllm --print-out-paths)/python"

python3 << 'EOF'
import tensorrt_llm.bindings.executor as trtllm
from transformers import AutoTokenizer

engine_dir = "/nix/store/<hash>-trtllm-engine-qwen3-32b-nvfp4-1.0.0"
executor = trtllm.Executor(engine_dir, trtllm.ModelType.DECODER_ONLY, trtllm.ExecutorConfig(max_beam_width=1))
tok = AutoTokenizer.from_pretrained(engine_dir, trust_remote_code=True)

prompt = "<|im_start|>user\nHello<|im_end|>\n<|im_start|>assistant\n"
request = trtllm.Request(
    input_token_ids=tok.encode(prompt),
    max_tokens=100,
    streaming=False,
    end_id=tok.eos_token_id,
    pad_id=tok.eos_token_id
)
responses = executor.await_responses(executor.enqueue_request(request))
print(tok.decode(responses[0].result.output_token_ids[0]))
EOF
```

## Triton Server

`mkTritonServerRuntime` creates a Triton server wrapper that:
1. Looks for engine at `$TRTLLM_ENGINE_PATH` or `~/.cache/trtllm-engines/<name>/`
2. Downloads tokenizer from HuggingFace if needed
3. Creates model repository with preprocessing/tensorrt_llm/postprocessing/ensemble models
4. Launches Triton with proper LD_LIBRARY_PATH

```bash
# Using symlink (recommended)
ln -sf /nix/store/<hash>-trtllm-engine-qwen3-32b-nvfp4-1.0.0 ~/.cache/trtllm-engines/qwen3
nix run .#tritonserver-qwen3

# Or with explicit path
TRTLLM_ENGINE_PATH=/path/to/engine nix run .#tritonserver-qwen3
```

## OpenAI Proxy

`nix/openai-proxy.nix` provides an OpenAI-compatible HTTP proxy over Triton's gRPC interface:

- Handles streaming (TRT-LLM returns one token per response)
- Applies chat template from tokenizer
- Exposes `/v1/chat/completions` and `/v1/completions`

```bash
nix run .#openai-qwen3  # Connects to localhost:8001 (Triton gRPC)
curl http://localhost:9000/v1/chat/completions \
  -d '{"model":"qwen3","messages":[{"role":"user","content":"Hello"}],"stream":true}'
```

## Adding New Models

1. Add to `flake.nix`:

```nix
my-model-engine = engines.mkEngine {
  name = "my-model";
  hfModel = "nvidia/My-Model-NVFP4";
  quantization = "NVFP4";
};

tritonserver-my-model = engines.mkTritonServerRuntime {
  name = "my-model";
  tokenizerModel = "nvidia/My-Model-NVFP4";
};
```

2. Build: `nix build .#my-model-engine --option sandbox false`

3. Link: `ln -sf result ~/.cache/trtllm-engines/my-model`

4. Run: `nix run .#tritonserver-my-model`

## Troubleshooting

### Build hangs forever
The 600s timeout should kill the process. If it still hangs, check if `rank0.engine` exists in the build directory and kill manually.

### "Engine not found" error
Ensure the symlink at `~/.cache/trtllm-engines/<name>` points to a valid engine directory containing `rank0.engine`.

### Garbage output (repeating tokens)
The engine was built without proper quantization. Rebuild with `--quantization NVFP4` for NVFP4 models.

### GPU memory errors
Reduce `maxBatchSize` or `maxSeqLen` in the engine config.
