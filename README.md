# nvidia-sdk

Production-grade NVIDIA CUDA SDK for NixOS with complete driver integration, container runtime support, and headless server capabilities.

**📚 [Complete Documentation Index](DOCS.md)**

**Key Features:**
- ✅ Complete CUDA 13.x SDK (toolkit, cuDNN, NCCL, TensorRT, etc.)
- ✅ NixOS module with automatic driver management
- ✅ Container runtime support (Docker/Podman GPU access via CDI)
- ✅ nvidia-persistenced for headless/server reliability
- ✅ Driver 580.x series support with backward compatibility
- ✅ x86_64-linux and aarch64-linux support

## Quick Start

### As a Flake Input

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
            cudaVersion = "13.0.2";
            
            # Hardware config
            openKernelModule = true;  # For Turing+ GPUs
            opengl.enable = true;
            
            # Server features (all enabled by default)
            nvidiaPersistenced = true;  # Keep GPU initialized
            container.enable = true;     # Docker/Podman GPU access
            
            # CUDA exposure
            expose = "none";  # Don't pollute global namespace
            wrapPrograms = [ pkgs.python3 ];  # Wrap specific programs
          };
        }
      ];
    };
  };
}
```

## What You Get

### CUDA SDK Components

| Package | Version | Source |
|---------|---------|--------|
| **CUDA Toolkit** | 13.0.2 | NVIDIA installer |
| **cuDNN** | 9.17.0.29 | NVIDIA redistrib |
| **NCCL** | 2.28.9 | NGC container |
| **TensorRT** | 10.14.1.48 | NVIDIA redistrib |
| **cuTensor** | 2.4.1.4 | NVIDIA redistrib |
| **CUTLASS** | 3.8.0 | GitHub |
| **Triton Server** | 25.11 | NGC container |

### NixOS Module Features

#### 1. Automatic Driver Management

The module handles NVIDIA driver installation and configuration:

```nix
hardware.nvidia-sdk = {
  enable = true;
  cudaVersion = "13.0.2";  # Requires driver >= 580.95.05
  
  # Driver auto-managed by nixpkgs (recommended)
  # Or specify exact version with hashes (see docs)
};
```

**Driver Compatibility:**
- Drivers are backward compatible
- CUDA 13.0.2 requires driver ≥ 580.95.05
- Works with: 580.119.02, 580.126.09, any 580.x+

#### 2. NVIDIA Persistenced (Enabled by Default)

Keeps GPU initialized for headless/server workloads:

```nix
hardware.nvidia-sdk.nvidiaPersistenced = true;  # default
```

**Why you need this:**
- GPU stays initialized without X11/Wayland
- Eliminates cold-start delays (crucial for containers)
- Essential for production compute workloads
- Prevents random failures in containerized applications

**When to disable:**
- Laptops where battery life matters
- Desktop systems that power down GPU when idle

#### 3. Container Runtime Support (Enabled by Default)

Automatic Docker/Podman GPU access via CDI:

```nix
hardware.nvidia-sdk.container.enable = true;  # default
```

**What it does:**
- Installs nvidia-container-toolkit
- Enables CDI (Container Device Interface) in Docker
- Configures Podman if enabled

**Usage:**
```bash
# Docker
docker run --device nvidia.com/gpu=all nvidia/cuda:13.0.2-base nvidia-smi

# Docker Compose
services:
  gpu-workload:
    image: nvidia/cuda:13.0.2-base
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

#### 4. CUDA Exposure Control

Three modes for CUDA access:

**Mode 1: None (Recommended for Production)**
```nix
hardware.nvidia-sdk = {
  expose = "none";
  wrapPrograms = [ pkgs.python3 pkgs.julia ];
};
```
Explicit per-program CUDA access. Clean, no global pollution.

**Mode 2: System (Simple for Development)**
```nix
hardware.nvidia-sdk.expose = "system";
```
Adds CUDA to systemPackages. Globally available.

**Mode 3: Selective (Future)**
```nix
hardware.nvidia-sdk.expose = "selective";  # Uses envfs
```
FHS-compatible selective exposure (planned).

## Driver 580.x Series

### Compatibility Matrix

CUDA 13.0.2 works with any driver ≥ 580.95.05:

| Driver Version | Release Date | Status |
|----------------|--------------|--------|
| 580.65.06 | Nov 2024 | Minimum for CUDA 13.0.0 |
| 580.95.05 | Dec 2024 | Minimum for CUDA 13.0.2 |
| 580.119.02 | Dec 11, 2025 | ✅ Recommended |
| 580.126.09 | Jan 2026 | ✅ Latest stable |

### Checking Your Driver

```bash
# Kernel module version
cat /proc/driver/nvidia/version

# Userspace library version
nvidia-smi

# Check persistence mode
nvidia-smi | grep "Persistence-M"
# Should show "On" if nvidiaPersistenced is enabled
```

### Open vs Proprietary Driver

The 580.x series supports both:

**Open Kernel Module** (Turing+ GPUs):
```nix
hardware.nvidia-sdk.openKernelModule = true;
```

**Proprietary Driver** (All GPUs):
```nix
hardware.nvidia-sdk.openKernelModule = false;
```

## Command Line Usage

```bash
# Dev shell with full SDK
nix develop github:weyl-ai/nvidia-sdk

# Build individual components
nix build github:weyl-ai/nvidia-sdk#cuda
nix build github:weyl-ai/nvidia-sdk#cudnn
nix build github:weyl-ai/nvidia-sdk#nccl
nix build github:weyl-ai/nvidia-sdk#tensorrt
nix build github:weyl-ai/nvidia-sdk#nvidia-sdk  # Unified SDK

# GPU monitoring (nvidia-smi always available from driver)
nvidia-smi
# Install btop/nvtop separately via your preferred method
```

## Configuration Examples

### Example 1: Server/Compute Node

```nix
hardware.nvidia-sdk = {
  enable = true;
  cudaVersion = "13.0.2";
  
  # Server optimizations
  openKernelModule = true;
  powerManagement.enable = false;
  nvidiaPersistenced = true;  # Critical for servers
  container.enable = true;    # Docker GPU access
  
  # No global CUDA exposure
  expose = "none";
};
```

### Example 2: ML Development Workstation

```nix
hardware.nvidia-sdk = {
  enable = true;
  cudaVersion = "13.0.2";
  
  # Development setup
  expose = "system";  # Global CUDA access
  openKernelModule = true;
  
  # Desktop features
  opengl.enable = true;
  powerManagement.enable = true;  # Optional power management
};
```

### Example 3: Container Platform (Kubernetes/K3s)

```nix
hardware.nvidia-sdk = {
  enable = true;
  cudaVersion = "13.0.2";
  
  # Essential for K8s
  nvidiaPersistenced = true;  # Prevents GPU unload
  container.enable = true;    # Automatic GPU access
  
  expose = "none";  # Containers handle their own paths
};

# Then deploy NVIDIA device plugin:
# kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/main/deployments/static/nvidia-device-plugin.yml
```

## Module Options Reference

### Core Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable NVIDIA SDK |
| `cudaVersion` | string | null | CUDA version ("13.0.2") |
| `expose` | enum | "none" | How to expose CUDA: "none", "system", "selective" |
| `wrapPrograms` | [package] | [] | Programs to wrap with CUDA access |

### Driver Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `driver.version` | string | null | Exact driver version (optional) |
| `driver.sha256_64bit` | string | "" | x86_64 driver hash |
| `driver.openSha256` | string | "" | Open kernel module hash |
| `openKernelModule` | bool | false | Use open driver (Turing+) |

### Server/Container Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nvidiaPersistenced` | bool | **true** | Enable persistence daemon |
| `container.enable` | bool | **true** | Enable container GPU access |
| `powerManagement.enable` | bool | false | Enable power management |
| `opengl.enable` | bool | true | Enable OpenGL support |

### Monitoring Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `monitoring.enable` | bool | true | Documentation for monitoring tools |

**Note:** Monitoring tools (nvtop/btop) should be installed separately via your preferred method. `nvidia-smi` is always available from the driver.

## Architecture

### File Structure

```
nix/
├── versions.nix          # Single source of truth for versions
├── cuda.nix              # CUDA toolkit from installer
├── cudnn.nix             # cuDNN from redistrib
├── nccl.nix              # NCCL from NGC container
├── tensorrt.nix          # TensorRT from redistrib
├── cutensor.nix          # cuTensor from redistrib
├── cutlass.nix           # CUTLASS from GitHub
├── nvidia-sdk.nix        # Unified SDK package
├── tritonserver.nix      # Triton Inference Server
└── modules/
    └── nvidia-sdk.nix    # NixOS module

docs/
├── DRIVER-580-GUIDE.md   # Driver 580.x series guide
└── NIXOS-MODULE.md       # Complete module documentation

examples/
├── driver-580-config.nix # Example configuration
└── nixos-configuration.nix
```

### Design Principles

1. **Single Source of Truth**: All versions in `nix/versions.nix`
2. **Explicit Dependencies**: No global pollution unless requested
3. **Production-Ready**: Persistenced, container support, reliability
4. **Backward Compatible**: Driver compatibility clearly documented
5. **Composable**: Use as overlay, module, or both

## Troubleshooting

### GPU Not Found in Container

**Symptom:** `docker run --device nvidia.com/gpu=all` fails

**Solution:**
1. Check persistenced: `systemctl status nvidia-persistenced`
2. Verify CDI: Check Docker has `features.cdi = true`
3. Ensure driver loaded: `nvidia-smi`

### Driver/Library Version Mismatch

**Symptom:** `Failed to initialize NVML: Driver/library version mismatch`

**Cause:** Kernel module and userspace libraries don't match

**Solution:**
```bash
# Check versions
cat /proc/driver/nvidia/version  # Kernel module
nvidia-smi | head -3             # Userspace

# If mismatch, rebuild
sudo nixos-rebuild switch
```

### CUDA Not Found

**Symptom:** Programs can't find CUDA

**Solution:**
- If `expose = "none"`: Add program to `wrapPrograms`
- If `expose = "system"`: Restart shell to get new PATH
- Check: `echo $CUDA_PATH`

### Persistence Mode Disabled

**Symptom:** `Persistence-M` shows "Off" in nvidia-smi

**Solution:**
```nix
hardware.nvidia-sdk.nvidiaPersistenced = true;
```
Then: `sudo nixos-rebuild switch`

## Documentation

### User Documentation

- **[NixOS Module Reference](docs/NIXOS-MODULE.md)** - Complete module options and examples
- **[Driver 580.x Guide](docs/DRIVER-580-GUIDE.md)** - Driver compatibility and troubleshooting
- **[Example Configurations](examples/)** - Ready-to-use NixOS configs

### Development Documentation

- **[Blackwell Investigation](docs/archive/BLACKWELL-SM120-INVESTIGATION.md)** - SM120 CUTLASS bring-up journal
- **[CUDA stdenv Link Line](docs/archive/CUDA-STDENV-LINK-LINE.md)** - Manual compilation reference
- **[stdenv Architecture](docs/archive/stdenvs.md)** - Custom stdenv design notes

## Development

```bash
# Clone repo
git clone https://github.com/weyl-ai/nvidia-sdk
cd nvidia-sdk

# Enter dev shell
nix develop

# Build SDK
nix build .#nvidia-sdk

# Test NixOS module
nixos-rebuild build --flake .#test-vm
```

## Contributing

This is a production configuration used in production GPU clusters. Changes should:
1. Maintain backward compatibility
2. Be tested on real hardware
3. Follow the hypermodern style
4. Update documentation

## License

Proprietary - NVIDIA components subject to NVIDIA's EULA. Nix expressions are MIT.

## Support

- Issues: GitHub Issues
- Docs: `docs/` directory
- Examples: `examples/` directory

---

**Production-tested on:**
- 4x NVIDIA RTX PRO 6000 (Ampere)
- NVIDIA driver 580.119.02 (open kernel module)
- CUDA 13.0.2
- NixOS unstable (2026-01)
