# NixOS Module for NVIDIA CUDA

This NixOS module provides declarative configuration for NVIDIA CUDA toolkit and driver management.

## Quick Start

### 1. Add the flake input

In your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    libmodern-nvidia-sdk.url = "github:yourorg/libmodern-nvidia-sdk";
  };

  outputs = { nixpkgs, libmodern-nvidia-sdk, ... }: {
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inputs = { inherit libmodern-nvidia-sdk; }; };
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
    inputs.libmodern-nvidia-sdk.nixosModules.default
  ];

  nixpkgs.overlays = [
    inputs.libmodern-nvidia-sdk.overlays.default
  ];

  hardware.nvidia-sdk = {
    enable = true;
    cudaVersion = "13.0.2";  # Choose your CUDA version
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

### `hardware.nvidia-sdk.cudaVersion`

**Type:** `string` (nullable)
**Default:** `null` (uses latest)
**Available:** `"12.9.1"`, `"13.0.0"`, `"13.0.1"`, `"13.0.2"`, `"13.1"`

CUDA version to use. If null, uses latest nvidia-sdk.

Each version requires a minimum driver:
- **12.9.1**: driver ≥ 575.57.08
- **13.0.0**: driver ≥ 580.65.06
- **13.0.1**: driver ≥ 580.82.07
- **13.0.2**: driver ≥ 580.95.05
- **13.1**: driver ≥ 590.44.01

### `hardware.nvidia-sdk.driver.*`

**Type:** `attribute set`

Exact driver version configuration. All fields required when specifying a driver version.

- `version`: Driver version string (e.g., "580.119.02")
- `sha256_64bit`: SHA256 hash for x86_64 driver
- `sha256_aarch64`: SHA256 hash for aarch64 driver
- `openSha256`: SHA256 hash for open kernel module
- `settingsSha256`: SHA256 hash for nvidia-settings
- `persistencedSha256`: SHA256 hash for nvidia-persistenced

### `hardware.nvidia-sdk.expose`

**Type:** `enum ["none", "system", "selective"]`
**Default:** `"none"`

How to expose CUDA:
- `"none"`: No global exposure (use wrapPrograms for specific programs)
- `"system"`: Add to systemPackages (traditional approach)
- `"selective"`: Use envfs for FHS-compatible selective exposure

**Recommended:** `"none"` for production (explicit dependencies)

### `hardware.nvidia-sdk.wrapPrograms`

**Type:** `list of packages`
**Default:** `[]`

Programs to wrap with CUDA access. Each program will be wrapped to have `CUDA_PATH`, `LD_LIBRARY_PATH` set.

**Example:**
```nix
hardware.nvidia-sdk.wrapPrograms = [ pkgs.python3 pkgs.julia ];
```

### `hardware.nvidia-sdk.opengl.enable`

**Type:** `boolean`
**Default:** `true`

Enable OpenGL support (required for graphics).

### `hardware.nvidia-sdk.openKernelModule`

**Type:** `boolean`
**Default:** `false`

Use open-source kernel module (Turing+ GPUs only).

### `hardware.nvidia-sdk.powerManagement.enable`

**Type:** `boolean`
**Default:** `false`

Enable NVIDIA power management.

### `hardware.nvidia-sdk.monitoring.enable`

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

### `hardware.nvidia-sdk.nvidiaPersistenced`

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
    inputs.libmodern-nvidia-sdk.nixosModules.default
  ];

  nixpkgs.overlays = [
    inputs.libmodern-nvidia-sdk.overlays.default
  ];

  # NVIDIA SDK configuration
  hardware.nvidia-sdk = {
    enable = true;
    cudaVersion = "13.0.2";
    
    # Expose method
    expose = "system";  # or "none" for no global exposure
    
    # Wrap specific programs with CUDA
    wrapPrograms = [ pkgs.python3 ];
    
    # Optional: Exact driver version
    driver = {
      version = "580.119.02";
      sha256_64bit = "sha256-gCD139PuiK7no4mQ0MPSr+VHUemhcLqerdfqZwE47Nc=";
      openSha256 = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=";
      settingsSha256 = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=";
      persistencedSha256 = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=";
    };
    
    # Hardware options
    opengl.enable = true;
    openKernelModule = false;  # Set true for open driver
    powerManagement.enable = false;
    
    # GPU monitoring (enabled by default)
    monitoring.enable = true;
    
    # Container runtime support (enabled by default)
    container.enable = true;
    
    # NVIDIA Persistenced for headless/server use (enabled by default)
    nvidiaPersistenced = true;
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

```nix
hardware.nvidia.cuda.version = "13.1";  # Upgrade to CUDA 13.1
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
  cudaVersion = "13.0.2";
  
  # Specify exact driver version (optional)
  driver = {
    version = "580.119.02";
    sha256_64bit = "sha256-gCD139PuiK7no4mQ0MPSr+VHUemhcLqerdfqZwE47Nc=";
    sha256_aarch64 = "";  # If using ARM
    openSha256 = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=";
    settingsSha256 = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=";
    persistencedSha256 = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=";
  };
  
  # Use open-source kernel module (Turing+)
  openKernelModule = false;  # Set to true for open driver
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

To install CUDA only for specific users:

```nix
hardware.nvidia.cuda = {
  enable = true;
  version = "13.0.2";
  addToSystemPackages = false;  # Don't add to system
  setDefaultRuntime = false;    # Don't set global env vars
};

users.users.alice.packages = [ pkgs.cuda ];
users.users.bob.packages = [ pkgs.cuda ];
```

## Development Environments

For development work, you can use direnv/nix-shell instead of system-wide installation:

```nix
# shell.nix
{ pkgs ? import <nixpkgs> {
    overlays = [ (import ./path/to/libmodern-nvidia-sdk).overlays.default ];
  }
}:

pkgs.mkShell {
  buildInputs = [
    pkgs.cuda
    pkgs.cudnn
    pkgs.nccl
    pkgs.tensorrt
  ];

  shellHook = ''
    export CUDA_PATH=${pkgs.cuda}
    export LD_LIBRARY_PATH=${pkgs.cuda}/lib:$LD_LIBRARY_PATH
  '';
}
```

## Container Support

### Docker

```nix
virtualisation.docker = {
  enable = true;
  enableNvidia = true;  # Requires hardware.nvidia.cuda.enable
};
```

### Podman

```nix
virtualisation.podman = {
  enable = true;
  enableNvidia = true;
};
```

### Running containers

```bash
docker run --gpus all nvidia/cuda:13.0.2-base-ubuntu22.04 nvidia-smi
```

## Troubleshooting

### CUDA applications can't find driver

Make sure `opengl.enable = true` (default):

```nix
hardware.nvidia.cuda.opengl.enable = true;
```

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
  inputs.libmodern-nvidia-sdk.overlays.default
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
  nvidiaPersistenced = true;  # default
};
```

The daemon runs as a systemd service and starts automatically.

