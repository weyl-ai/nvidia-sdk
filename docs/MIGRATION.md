# Migration Guide: Old versions.nix to New Structure

This guide helps you migrate from the monolithic `versions.nix` to the new modular structure.

## Overview

The new structure provides:
- ✅ Better validation and error messages
- ✅ Easier version updates
- ✅ Clearer separation of concerns
- ✅ Type-safe version definitions

## Quick Migration

### Before (Old)
```nix
# In your flake.nix
versions = import ./nix/versions.nix;
```

### After (New)
```nix
# In your flake.nix
versions = import ./nix/versions { inherit lib; };
```

## Detailed Changes

### 1. Import Path

**Old:**
```nix
versions = import ./nix/versions.nix;
```

**New:**
```nix
versions = import ./nix/versions { inherit lib; };
```

### 2. Accessing Versions

**Old:**
```nix
versions.cuda.version
versions.cudnn.x86_64-linux.hash
```

**New:**
```nix
versions.cuda.version
versions.cudnn.x86_64-linux.hash
# Same! No changes needed here
```

### 3. Compatibility Checking

**Old:**
No built-in compatibility checking.

**New:**
```nix
# Check if CUDA version is compatible with driver
versions.lib.checkCompatibility "13.1" "590.44.01"
# Returns: { compatible = true; reason = "OK"; status = "current"; }

# Assert compatibility at eval time
versions.lib.assertCompatible "13.1" "590.44.01"
# Throws assertion error if incompatible
```

### 4. Validation

**Old:**
No validation - errors at build time.

**New:**
```nix
# All versions are validated at import time
# Errors are caught early with clear messages

# Example error:
# version validation failed: driver: hash appears to be a placeholder
```

## File Structure Changes

### Old Structure
```
nix/
├── versions.nix          # Everything in one file (235 lines)
```

### New Structure
```
nix/
├── versions/
│   ├── default.nix       # Entry point with validation
│   ├── cuda/
│   │   └── default.nix   # CUDA versions
│   ├── cudnn/
│   │   └── default.nix   # cuDNN versions
│   ├── nccl/
│   │   └── default.nix   # NCCL versions
│   ├── tensorrt/
│   │   └── default.nix   # TensorRT versions
│   ├── cutensor/
│   │   └── default.nix   # cuTensor versions
│   ├── cutlass/
│   │   └── default.nix   # CUTLASS versions
│   ├── ngc/
│   │   └── default.nix   # NGC container versions
│   ├── driver/
│   │   └── default.nix   # Driver versions
│   ├── nsight/
│   │   └── default.nix   # Nsight versions
│   └── sm/
│       └── default.nix   # SM architecture definitions
```

## Backward Compatibility

The new structure maintains backward compatibility:

```nix
# Old import still works (with deprecation warning)
versions = import ./nix/versions.nix;

# But you should migrate to:
versions = import ./nix/versions { inherit lib; };
```

## Migration Checklist

- [ ] Update import statements to pass `lib`
- [ ] Test that all version references still work
- [ ] Update any custom version handling code
- [ ] Add compatibility checks where needed
- [ ] Update documentation references
- [ ] Run test suite to verify everything works

## Troubleshooting

### Issue: "cannot import versions.nix directly"
**Solution:** Use the new import pattern:
```nix
versions = import ./nix/versions { inherit lib; };
```

### Issue: "undefined variable 'lib'"
**Solution:** Make sure to pass `lib` from your nixpkgs:
```nix
{ pkgs, lib, ... }:
let
  versions = import ./nix/versions { inherit lib; };
in
  # ...
```

### Issue: "validation failed: driver hash is placeholder"
**Solution:** This is expected - update the driver hash in `nix/versions/driver/default.nix`:
```bash
nix-prefetch-url https://us.download.nvidia.com/XFree86/Linux-x86_64/590.44.01/NVIDIA-Linux-x86_64-590.44.01.run
```

## Support

For migration assistance:
- Check the [troubleshooting section](#troubleshooting) above
- Review the [test suite](../tests/) for examples
- Open an issue on GitHub with the "migration" label
