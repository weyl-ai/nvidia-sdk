# Standard Environments

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Philosophy

A stdenv defines how the universe builds itself.

These stdenvs embody the Weyl Standard:

| Principle | Implementation |
|-----------|----------------|
| **Performance** | `-O2` — real optimization, not debug toys |
| **Visibility** | `-g3 -gdwarf-5` — full symbols, gdb works |
| **Predictability** | No hardening — predictable addresses, no overhead |
| **Traceability** | Frame pointers always — stack traces work |

## The Stdenvs

```
┌─────────────────────────┬────────────────────────────────────────┐
│ weyl-stdenv             │ glibc dynamic, clang, C++23            │
│ weyl-stdenv-static      │ glibc static (mostly)                  │
│ weyl-stdenv-musl        │ musl + libc++, C++23                   │
│ weyl-stdenv-musl-static │ fully static, deploy anywhere          │
│ weyl-stdenv-cuda        │ CUDA device + host, C++23              │
└─────────────────────────┴────────────────────────────────────────┘
```

## Usage

### Basic

```nix
{ pkgs, ... }:
pkgs.weyl-stdenv.mkDerivation {
  name = "my-app";
  src = ./.;
  buildPhase = "$CXX -o app main.cpp";
}
```

### Portable Static Binary

```nix
pkgs.weyl-stdenv-musl-static.mkDerivation {
  name = "my-tool";
  src = ./.;
  buildPhase = "$CXX -o tool main.cpp";
  # Result: single static binary, runs anywhere
}
```

### CUDA Kernel

```nix
pkgs.weyl-stdenv-cuda.mkDerivation {
  name = "my-kernel";
  src = ./.;
  buildPhase = "$CXX -o kernel main.cu";
  # CUDA_HOME and CUDA_PATH are set
}
```

## Cross-Compilation

Build on x86_64 workstation, deploy to ARM:

```nix
# Grace Hopper (aarch64 + Hopper GPU)
pkgs.weyl-cross.grace.mkDerivation {
  name = "grace-app";
  src = ./.;
}

# Jetson Orin (aarch64 + Ampere GPU)
pkgs.weyl-cross.jetson.mkDerivation {
  name = "jetson-app";
  src = ./.;
}

# Generic aarch64
pkgs.weyl-cross.aarch64.mkDerivation {
  name = "arm-app";
  src = ./.;
}
```

From aarch64, target x86_64:

```nix
pkgs.weyl-cross.x86-64.mkDerivation {
  name = "x86-app";
  src = ./.;
}
```

## The Flags

### Optimization

```
-O2                       Real performance
```

### Debug Information

```
-g3                       Maximum info (includes macros)
-gdwarf-5                 Modern format, best tooling
-fno-limit-debug-info     Don't truncate for speed
-fstandalone-debug        Full info for system headers
```

### Frame Pointers

```
-fno-omit-frame-pointer        Keep RBP/X29
-mno-omit-leaf-frame-pointer   Even in leaf functions
```

### No Hardening

```
-U_FORTIFY_SOURCE              Remove buffer "protection"
-D_FORTIFY_SOURCE=0            Really remove it
-fno-stack-protector           No canaries
-fno-stack-clash-protection    No stack clash mitigation
-fcf-protection=none           No CET (x86_64 only)
```

### Nix Attributes

```nix
dontStrip = true;              # Symbols stay
separateDebugInfo = false;     # Debug info in binary
hardeningDisable = [ "all" ];  # Kill nix wrapper hardening
```

## Verification

### Check Symbols Present

```bash
nm ./app | grep -E "^[0-9a-f]+ T"
```

### Check Debug Info

```bash
readelf --debug-dump=info ./app | head
```

### Check Not Stripped

```bash
file ./app | grep "not stripped"
```

### Check Static

```bash
file ./app | grep "statically linked"
ldd ./app  # Should fail
```

### GDB Works

```bash
gdb -ex "break main" -ex "run" -ex "bt" -ex "quit" ./app
```

## Introspection

```bash
# View configuration
nix eval .#weyl-stdenv-info --json | jq

# Check stdenv passthru
nix eval .#weyl-stdenv.passthru.weyl --json
```

## Architecture

```
weyl-stdenv-overlay
├── platform detection
│   ├── x86_64-linux
│   └── aarch64-linux
├── gcc paths (auto-detected)
│   ├── include
│   ├── include-arch
│   └── lib
├── flags
│   ├── opt-flags      (-O2)
│   ├── debug-flags    (-g3 -gdwarf-5 ...)
│   ├── frame-flags    (-fno-omit-frame-pointer ...)
│   └── no-harden-flags
├── clang wrappers
│   ├── clang-glibc    (clang + gcc15 libstdc++)
│   └── clang-musl     (clang + musl + libc++)
├── native stdenvs
│   ├── weyl-stdenv
│   ├── weyl-stdenv-static
│   ├── weyl-stdenv-musl
│   ├── weyl-stdenv-musl-static
│   └── weyl-stdenv-cuda
└── cross stdenvs
    ├── weyl-cross.grace
    ├── weyl-cross.jetson
    ├── weyl-cross.aarch64
    └── weyl-cross.x86-64
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
