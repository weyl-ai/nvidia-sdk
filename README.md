# nvidia-sdk

NVIDIA CUDA SDK for NixOS — the complete CUDA 13.1 development environment with Blackwell SM120 support.

All binaries are fetched directly from NVIDIA's official distribution channels. This project provides Nix expressions that package NVIDIA's software for reproducible builds on NixOS.

## Quick Start

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nvidia-sdk.url = "github:weyl-ai/nvidia-sdk";
  };

  outputs = { self, nixpkgs, nvidia-sdk }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nvidia-sdk.nixosModules.default
        {
          nixpkgs.overlays = [ nvidia-sdk.overlays.default ];
          
          hardware.nvidia-sdk = {
            enable = true;
            driver.open = true;  # Open kernel module (Turing+)
          };
        }
      ];
    };
  };
}
```

## Components

| Package | Version | Source | License |
|---------|---------|--------|---------|
| CUDA Toolkit | 13.1 | developer.download.nvidia.com | NVIDIA EULA |
| cuDNN | 9.17.0.29 | developer.download.nvidia.com | NVIDIA SLA |
| NCCL | 2.28.9 | PyPI (files.pythonhosted.org) | BSD-3-Clause |
| TensorRT | 10.15.1.29 | developer.download.nvidia.com | NVIDIA SLA |
| cuTensor | 2.4.1.4 | developer.download.nvidia.com | NVIDIA SLA |
| CUTLASS | 4.3.3 | GitHub | BSD-3-Clause |

## Supported Architectures

| Architecture | Compute Capability | Hardware |
|--------------|-------------------|----------|
| Blackwell (RTX) | SM120 | RTX 50 series |
| Blackwell (DC) | SM100, SM121 | B100, B200, GB200 |
| Hopper | SM90 | H100, H200, GH200 |
| Ada Lovelace | SM89 | RTX 40 series, L4, L40 |
| Ampere | SM80, SM86 | A100, RTX 30 series |

## NixOS Module

The module configures:

- **Driver management** — automatic NVIDIA driver installation
- **Container runtime** — Docker/Podman GPU access via CDI
- **Persistence daemon** — keeps GPU initialized for headless servers
- **Environment variables** — `CUDA_PATH`, `CUDA_HOME` set globally

```nix
hardware.nvidia-sdk = {
  enable = true;
  
  driver.open = true;       # Open kernel module (Turing+ required)
  persistenced = true;      # Keep GPU initialized (default: true)
  container.enable = true;  # Docker/Podman GPU access (default: true)
  systemPackages = true;    # Add nvidia-sdk to PATH (default: true)
  monitoring = true;        # Install nvtop + btop (default: true)
};
```

## Command Line

```bash
# Development shell
nix develop github:weyl-ai/nvidia-sdk

# Build individual packages
nix build github:weyl-ai/nvidia-sdk#nvidia-sdk
nix build github:weyl-ai/nvidia-sdk#cuda
nix build github:weyl-ai/nvidia-sdk#cudnn
nix build github:weyl-ai/nvidia-sdk#tensorrt

# Validate installation
nvidia-sdk-validate
```

## Driver Compatibility

CUDA 13.1 requires driver ≥ 590.44.01. The module uses `nvidiaPackages.latest` from nixpkgs by default.

## Source Provenance

All NVIDIA binaries are fetched from official NVIDIA distribution channels with pinned SHA-256 hashes:

- **CUDA Toolkit**: `developer.download.nvidia.com/compute/cuda/`
- **cuDNN**: `developer.download.nvidia.com/compute/cudnn/redist/`
- **TensorRT**: `developer.download.nvidia.com/compute/machine-learning/tensorrt/`
- **cuTensor**: `developer.download.nvidia.com/compute/cutensor/redist/`
- **NCCL**: `files.pythonhosted.org` (PyPI wheel, BSD-3-Clause)
- **CUTLASS**: `github.com/NVIDIA/cutlass` (BSD-3-Clause)

No third-party mirrors are used. The hash is the security boundary — any mismatch aborts the build.

## License

- **Nix expressions**: MIT License (see [LICENSE](LICENSE))
- **NVIDIA binaries**: Subject to [NVIDIA EULA](https://docs.nvidia.com/cuda/eula/)
- **NCCL, CUTLASS**: BSD-3-Clause

See [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md) for details.

By using this SDK, you agree to comply with the [NVIDIA End User License Agreement](https://www.nvidia.com/en-us/drivers/nvidia-license/).

## Resources

- [NVIDIA CUDA Toolkit](https://developer.nvidia.com/cuda-toolkit)
- [NVIDIA cuDNN](https://developer.nvidia.com/cudnn)
- [NVIDIA TensorRT](https://developer.nvidia.com/tensorrt)
- [NVIDIA CUTLASS](https://github.com/NVIDIA/cutlass)
- [Buy NVIDIA DGX](https://www.nvidia.com/en-us/data-center/dgx-platform/)
