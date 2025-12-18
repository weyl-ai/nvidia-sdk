# NixOS Module for NVIDIA CUDA

This NixOS module provides declarative configuration for NVIDIA CUDA toolkit and driver management.

## Quick Start

### 1. Add the flake input

In your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nvidia-sdk.url = "github:weyl-ai/nvidia-sdk";
  };

  outputs = { nixpkgs, nvidia-sdk, ... }: {
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inputs = { inherit nvidia-sdk; }; };
      modules = [
        ./configuration.nix
      ];
    };
  };
}
```

### 2. Import the module and overlay

In your `configuration.nix`:

```nix
{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.nvidia-sdk.nixosModules.default
  ];

  nixpkgs.overlays = [
    inputs.nvidia-sdk.overlays.default
  ];

  hardware.nvidia-sdk = {
    enable = true;
    driver.open = true;  # Open kernel module (Turing+)
  };
}
```

### 3. Rebuild your system

```bash
sudo nixos-rebuild switch --flake .#yourhostname
```

## Configuration Options

### `hardware.nvidia-sdk.enable`

**Type:** `boolean`
**Default:** `false`

Enable NVIDIA SDK (CUDA + driver with exact version control).

### `hardware.nvidia-sdk.driver.package`

**Type:** `package`
**Default:** `config.boot.kernelPackages.nvidiaPackages.latest`

The NVIDIA driver package to use. Override to pin a specific driver version.

### `hardware.nvidia-sdk.driver.open`

**Type:** `boolean`
**Default:** `true`

Use open-source kernel modules (Turing+ GPUs required).

### `hardware.nvidia-sdk.systemPackages`

**Type:** `boolean`
**Default:** `true`

Add `nvidia-sdk` to `environment.systemPackages`. When true, also sets
`CUDA_PATH` and `CUDA_HOME` environment variables.

### `hardware.nvidia-sdk.monitoring`

**Type:** `boolean`
**Default:** `true`

Install GPU monitoring tools:
- **nvtop**: GPU process monitor (like htop for GPUs)
- **btop**: System monitor with NVIDIA GPU support via NVML

`nvidia-smi` is always available from the driver.

### `hardware.nvidia-sdk.container.enable`

**Type:** `boolean`
**Default:** `true`

Enable NVIDIA Container Toolkit for Docker/Podman GPU access.

**What it does:**
- Installs and configures `nvidia-container-toolkit`
- Enables CDI (Container Device Interface) for Docker
- Configures Podman if enabled
- Allows containers to access GPUs with `--device nvidia.com/gpu=all`

**Usage in Docker:**
```bash
docker run --rm --device nvidia.com/gpu=all ubuntu:latest nvidia-smi
```

**Usage in Docker Compose:**
```yaml
services:
  gpu-service:
    image: ubuntu:latest
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

### `hardware.nvidia-sdk.persistenced`

**Type:** `boolean`
**Default:** `true`

Enable nvidia-persistenced daemon for headless/server setups.

**Why you need this:**
- Keeps GPU initialized even without X11/Wayland
- Essential for headless compute workloads
- Faster CUDA initialization (no cold-start delay)
- Required for container workloads in production
- Reduces latency for first GPU access

**When to enable:**
- ✅ Server/compute-only systems
- ✅ Containers and Kubernetes
- ✅ Headless GPU workloads
- ✅ Any non-desktop use case

**When to disable:**
- ❌ Desktop systems (optional, but harmless)
- ❌ Laptops where you want GPU to power down

## Complete Example

```nix
{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.nvidia-sdk.nixosModules.default
  ];

  nixpkgs.overlays = [
    inputs.nvidia-sdk.overlays.default
  ];

  # NVIDIA SDK configuration
  hardware.nvidia-sdk = {
    enable = true;

    # Driver
    driver.open = true;  # Open kernel module (Turing+)
    # driver.package = config.boot.kernelPackages.nvidiaPackages.stable;

    # System integration
    systemPackages = true;    # nvidia-sdk in PATH, CUDA_PATH set
    monitoring = true;        # nvtop + btop with NVML

    # Server features (all enabled by default)
    persistenced = true;       # Keep GPU initialized
    container.enable = true;   # Docker/Podman GPU via CDI
  };

  # Add SDK components (available via overlay)
  environment.systemPackages = with pkgs; [
    cudnn              # Deep learning
    nccl               # Multi-GPU communication
    tensorrt           # Inference optimization
    cutensor           # Tensor operations
    cuda-samples       # Example programs
    nsight-gui-apps    # Profiling tools
  ];

  # Docker with NVIDIA runtime
  virtualisation.docker = {
    enable = true;
    enableNvidia = true;
  };
}
```

## Architecture Support

The module supports both architectures:

- **x86_64-linux**: Full support with all CUDA versions
- **aarch64-linux**: Full support (Grace Hopper, Jetson)

## What This Module Does

1. **Enables NVIDIA Driver**: Automatically configures `services.xserver.videoDrivers`
2. **Installs CUDA Toolkit**: Adds the specified CUDA version to system packages
3. **Configures OpenGL/Vulkan**: Sets up hardware acceleration
4. **Sets Environment Variables**: Configures `CUDA_PATH`, `CUDA_HOME`, `LD_LIBRARY_PATH`
5. **Validates Configuration**: Checks driver compatibility and provides warnings
6. **Creates Metadata File**: Stores version info in `/etc/cuda-version`

## Version Switching

You can switch CUDA versions by changing the `version` option and rebuilding:

```bash
# Upgrade by updating the nvidia-sdk flake input:
nix flake update nvidia-sdk
sudo nixos-rebuild switch
```

The module will:
- Install the new CUDA toolkit
- Update environment variables
- Warn if driver update is needed
- Preserve your configuration

## Driver Management

The module provides **exact driver version control** via the `driver` option. This allows you to specify the precise driver version with all required hashes.

### Driver Compatibility

NVIDIA drivers are **backward compatible**. The `driver` field in versions.nix specifies the **minimum required driver** for each CUDA version.

**Example**: CUDA 13.0.2 requires driver ≥ 580.95.05

Compatible drivers include:
- 580.95.05 (minimum)
- 580.119.02 ✓
- 580.126.09 ✓  
- Any newer 580.x or 590.x driver ✓

### Specifying Exact Driver Version

```nix
hardware.nvidia-sdk = {
  enable = true;

  # Override driver package (optional — defaults to nvidiaPackages.latest)
  driver.package = config.boot.kernelPackages.nvidiaPackages.stable;
  driver.open = true;  # Open kernel module (Turing+)
};
```

### Getting Driver Hashes

To obtain hashes for a specific driver version:

```bash
# x86_64 driver
nix-prefetch-url https://us.download.nvidia.com/XFree86/Linux-x86_64/580.119.02/NVIDIA-Linux-x86_64-580.119.02.run

# Convert to SRI format
nix hash convert --hash-algo sha256 <hash-output>

# Open kernel module (add -open suffix)
nix-prefetch-url https://us.download.nvidia.com/XFree86/Linux-x86_64/580.119.02/NVIDIA-Linux-x86_64-580.119.02-open.run
```

### Using NixOS Default Driver

If you don't specify a driver version, the module falls back to nixpkgs' stable driver:

```nix
hardware.nvidia-sdk = {
  enable = true;
  cudaVersion = "13.0.2";
  # driver version not specified - uses nixpkgs stable driver
};
```

## Per-User Installation

To install CUDA only for specific users (not system-wide):

```nix
hardware.nvidia-sdk = {
  enable = true;
  driver.open = true;
  systemPackages = false;  # Don't add nvidia-sdk to system PATH
};

# Add nvidia-sdk to specific users instead
users.users.alice.packages = [ pkgs.nvidia-sdk ];
users.users.bob.packages = [ pkgs.nvidia-sdk ];
```

## Development Environments

For development work, you can use direnv/nix-shell instead of system-wide installation:

```bash
# Use the flake dev shell directly:
nix develop github:weyl-ai/nvidia-sdk

# Or in a shell.nix with the overlay:
```
```nix
{ pkgs ? import <nixpkgs> {
    overlays = [ (builtins.getFlake "github:weyl-ai/nvidia-sdk").overlays.default ];
  }
}:

pkgs.mkShell {
  buildInputs = [ pkgs.nvidia-sdk ];

  shellHook = ''
    export CUDA_PATH=${pkgs.nvidia-sdk}
    export LD_LIBRARY_PATH=${pkgs.nvidia-sdk}/lib64:$LD_LIBRARY_PATH
  '';
}
```

## Container Support

### Docker

When `container.enable = true` (default), the module automatically configures
Docker with CDI support. Just enable Docker:

```nix
virtualisation.docker.enable = true;
```

### Running containers

```bash
# CDI-based GPU access (recommended)
docker run --rm --device nvidia.com/gpu=all ubuntu:latest nvidia-smi
```

## Troubleshooting

### CUDA applications can't find driver

The module enables `hardware.graphics` automatically. Check that `hardware.nvidia-sdk.enable = true` is set.

### Version mismatch errors

Check the installed versions:

```bash
cat /etc/cuda-version
nvidia-smi  # Shows driver version
nvcc --version  # Shows CUDA version
```

### Driver not loading

Rebuild with driver debug info:

```bash
sudo nixos-rebuild switch --show-trace
dmesg | grep -i nvidia
```

### Multiple CUDA versions

Each CUDA version is isolated. You can switch between them, but only one is active at a time.

To use multiple versions simultaneously, use nix-shell environments.

## Advanced: Custom Overlays

You can combine with your own overlays:

```nix
nixpkgs.overlays = [
  inputs.nvidia-sdk.overlays.default
  (final: prev: {
    # Custom CUDA package
    my-cuda-app = final.callPackage ./my-cuda-app.nix {
      cuda = final.cuda;
      cudnn = final.cudnn;
    };
  })
];
```

## Migration from Manual Installation

If you previously installed CUDA manually:

1. Remove manual CUDA packages from `environment.systemPackages`
2. Remove manual environment variable configuration
3. Enable the module with your desired version
4. Rebuild: `sudo nixos-rebuild switch`

The module handles everything automatically.

## See Also

- [Main README](../README.md)
- [Example Configuration](../examples/nixos-configuration.nix)
- [NVIDIA Documentation](https://docs.nvidia.com/cuda/)
- [NixOS NVIDIA Driver Wiki](https://nixos.wiki/wiki/Nvidia)

## Container Support

The module provides full GPU access for containers via NVIDIA Container Toolkit.

### Docker

When `container.enable = true` (default), the module automatically:
1. Installs `nvidia-container-toolkit`
2. Enables CDI (Container Device Interface) in Docker
3. Configures runtime for GPU access

**Run a container with GPU:**
```bash
docker run --rm --device nvidia.com/gpu=all ubuntu:latest nvidia-smi
```

**Docker Compose:**
```yaml
services:
  gpu-workload:
    image: nvidia/cuda:13.0.2-base-ubuntu22.04
    command: nvidia-smi
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1  # or "all"
              capabilities: [gpu]
```

### Podman

Podman is automatically configured if `virtualisation.podman.enable = true`:

```bash
podman run --rm --device nvidia.com/gpu=all ubuntu:latest nvidia-smi
```

### Kubernetes/K3s

For Kubernetes GPU support, the NVIDIA Device Plugin is required:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: nvidia-device-plugin-ds
  template:
    metadata:
      labels:
        name: nvidia-device-plugin-ds
    spec:
      containers:
      - image: nvcr.io/nvidia/k8s-device-plugin:latest
        name: nvidia-device-plugin-ctr
```

Then request GPUs in pod specs:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  containers:
  - name: cuda-container
    image: nvidia/cuda:13.0.2-base-ubuntu22.04
    resources:
      limits:
        nvidia.com/gpu: 1
```

## NVIDIA Persistenced

The `nvidiaPersistenced` option enables the NVIDIA persistence daemon, which is **essential for server/compute workloads**.

### What It Does

Without persistenced, the GPU driver:
- Unloads when no X11/Wayland session is active
- Has cold-start delays on first access
- Can cause issues with containers

With persistenced enabled:
- GPU stays initialized 24/7
- Instant CUDA access (no initialization delay)
- Container workloads work reliably
- Background compute jobs don't fail

### When To Use

**Enable (default) for:**
- Servers and headless systems
- Container/Docker/Kubernetes workloads
- Compute-only systems (no GUI)
- ML/AI training servers
- Render farms

**Disable for:**
- Laptops where battery life matters
- Desktop systems that power down GPU when idle
- Systems that use GPU only occasionally

### Configuration

```nix
hardware.nvidia-sdk = {
  enable = true;
  persistenced = true;  # default
};
```

The daemon runs as a systemd service and starts automatically.

