# Driver 580.x Series Guide

## Quick Reference

Driver 580.x series is compatible with:
- CUDA 13.0.0 (requires ≥ 580.65.06)
- CUDA 13.0.1 (requires ≥ 580.82.07)  
- CUDA 13.0.2 (requires ≥ 580.95.05)

All driver versions in the 580.x series are backward compatible.

## Common Driver Versions

| Driver Version | Release Date | Notes |
|----------------|--------------|-------|
| 580.65.06 | Nov 2024 | Initial 580 series release |
| 580.95.05 | Dec 2024 | Bundled with CUDA 13.0.2 |
| 580.119.02 | Dec 11, 2025 | Recommended/Certified release |
| 580.126.09 | Jan 2026 | Latest stable |

## Checking Your Driver Version

```bash
# Kernel module version
cat /proc/driver/nvidia/version

# Userspace library version
readlink /run/opengl-driver/lib/libnvidia-ml.so.1

# Full system info
nvidia-smi
```

## Configuration Examples

### Automatic Driver (Recommended)

Let NixOS manage the driver automatically:

```nix
hardware.nvidia-sdk = {
  enable = true;
  cudaVersion = "13.0.2";
  openKernelModule = true;  # if using open driver
};
```

This uses whatever driver nixpkgs provides (typically `stable`, `beta`, or `latest`).

### Manual Driver Version

If you need a specific driver version and have all the hashes:

```nix
hardware.nvidia-sdk = {
  enable = true;
  cudaVersion = "13.0.2";
  
  driver = {
    version = "580.119.02";
    sha256_64bit = "sha256-gCD139PuiK7no4mQ0MPSr+VHUemhcLqerdfqZwE47Nc=";
    openSha256 = "sha256-XXXX...";
    settingsSha256 = "sha256-XXXX...";
    persistencedSha256 = "sha256-XXXX...";
  };
  
  openKernelModule = true;
};
```

**Note:** Getting all required hashes can be complex. Option 1 (automatic) is easier and works for most cases.

## Troubleshooting

### Version Mismatch Between Kernel and Userspace

**Symptom:**
```
Kernel module: 580.119.02
Userspace libs: 580.126.09
```

**This is usually fine** - NixOS can have different versions as long as they're compatible. If you get errors:

1. Rebuild your system to sync versions:
   ```bash
   sudo nixos-rebuild switch
   ```

2. Or explicitly set the driver version in your config (requires all hashes)

### CUDA Programs Can't Find Driver

Ensure OpenGL support is enabled:

```nix
hardware.nvidia-sdk.opengl.enable = true;
```

### Driver Not Loading

Check dmesg for errors:
```bash
dmesg | grep -i nvidia
lsmod | grep nvidia
```

Verify the kernel module matches your configuration:
```bash
cat /proc/driver/nvidia/version
```

## Open vs Proprietary Driver

The 580.x series supports both driver types:

**Open Kernel Module** (Turing+ GPUs):
```nix
hardware.nvidia-sdk.openKernelModule = true;
```

**Proprietary Driver** (all GPUs):
```nix
hardware.nvidia-sdk.openKernelModule = false;
```

Check which you're using:
```bash
cat /proc/driver/nvidia/version | grep "Open Kernel Module"
```

## See Also

- [NixOS Module Documentation](NIXOS-MODULE.md)
- [Main README](../README.md)
- [NVIDIA 580 Series Release Notes](https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-580/index.html)
