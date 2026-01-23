# CUDA stdenv Link Line Reference

## Working Manual Compilation Command

Verified working on 2026-01-05 with:
- Clang 22.0.0git (llvm-git)
- GCC 15.2.0 (libstdc++)
- CUDA 13.0.2
- Blackwell SM120

```bash
GCC15_CC=/nix/store/rmv9ajkrzg19k0ax5kq3wq9xcibman7g-gcc-15.2.0
GLIBC=/nix/store/xx7cm72qy2c0643cm1ipngd87aqwkcdp-glibc-2.40-66
GLIBC_DEV=/nix/store/gi4cz4ir3zlwhf1azqfgxqdnczfrwsr7-glibc-2.40-66-dev
STDENV_LIB=/nix/store/xm08aqdd7pxcdhm0ak6aqb1v7hw5q6ri-gcc-14.3.0-lib
CUDA=/nix/store/ilknw50lwyv2wn9py1h2zbxsz4ixq4b5-cuda-13.0.2

./llvm-git/bin/clang++ test.cu \
  --cuda-path=$CUDA \
  --cuda-gpu-arch=sm_120 \
  -I$GCC15_CC/include/c++/15.2.0 \
  -I$GCC15_CC/include/c++/15.2.0/x86_64-unknown-linux-gnu \
  -I$GLIBC_DEV/include \
  -B$GLIBC/lib \
  -B$GCC15_CC/lib/gcc/x86_64-unknown-linux-gnu/15.2.0 \
  -L$GCC15_CC/lib/gcc/x86_64-unknown-linux-gnu/15.2.0 \
  -L$GCC15_CC/lib \
  -L$STDENV_LIB/lib \
  -L$GLIBC/lib \
  -L$CUDA/lib64 \
  -lcudart \
  -lstdc++ \
  -o test
```

## Flag-by-Flag Breakdown

### CUDA Configuration Flags

| Flag | Purpose | Required For |
|------|---------|--------------|
| `--cuda-path=$CUDA` | Points clang to CUDA SDK installation | Finding libdevice, CUDA headers, runtime |
| `--cuda-gpu-arch=sm_120` | Target architecture for device code | SM120 Blackwell codegen |

### Include Paths (-I)

| Flag | Purpose | Provides |
|------|---------|----------|
| `-I$GCC15_CC/include/c++/15.2.0` | C++ standard library headers | `<iostream>`, `<vector>`, etc. |
| `-I$GCC15_CC/include/c++/15.2.0/x86_64-unknown-linux-gnu` | Architecture-specific C++ headers | Platform-specific type definitions |
| `-I$GLIBC_DEV/include` | C system headers | `<stdio.h>`, `<climits>`, `<limits.h>` |

**Critical**: All three `-I` paths are needed for device compilation. Clang's CUDA mode compiles device code in two passes (host + device), and both need these headers.

### Binary Search Paths (-B)

| Flag | Purpose | Provides |
|------|---------|----------|
| `-B$GLIBC/lib` | Search path for C runtime startup objects | `Scrt1.o`, `crti.o`, `crtn.o` |
| `-B$GCC15_CC/lib/gcc/x86_64-unknown-linux-gnu/15.2.0` | Search path for GCC runtime objects | `crtbeginS.o`, `crtendS.o` |

**Note**: `-B` flags tell the compiler where to find CRT (C Runtime) object files used during linking.

### Library Search Paths (-L)

| Flag | Purpose | Provides |
|------|---------|----------|
| `-L$GCC15_CC/lib/gcc/x86_64-unknown-linux-gnu/15.2.0` | GCC internal runtime directory | `libgcc.a` (static compiler runtime) |
| `-L$GCC15_CC/lib` | GCC library directory | `libstdc++.so`, `libstdc++.a` |
| `-L$STDENV_LIB/lib` | Nix stdenv.cc.cc.lib | `libgcc_s.so` (shared GCC runtime with pthread) |
| `-L$GLIBC/lib` | **CRITICAL** - glibc library directory | `libm.so` (math), `libc.so` (C library) |
| `-L$CUDA/lib64` | CUDA runtime libraries | `libcudart.so`, `libcudart_static.a` |

**Critical Missing Piece**: `-L$GLIBC/lib` was initially missing, causing linker errors for `-lm`. This path is essential.

### Explicit Libraries (-l)

| Flag | Purpose | Why Needed |
|------|---------|------------|
| `-lcudart` | Link CUDA runtime | Required for all CUDA programs (`<<<>>>`, `cudaMalloc`, etc.) |
| `-lstdc++` | Link C++ standard library | Required when using C++ stdlib (`std::cout`, etc.) |

**Note**: `-lm` (math library) is pulled in automatically via other dependencies, but only if `-L$GLIBC/lib` is in the search path.

## Component Requirements

### 1. LLVM Git HEAD (Clang 22.0.0git)
- **Why**: SM120 support only in mainline LLVM
- **Path**: Built via `nix/llvm-git.nix` from pinned llvm-project git
- **Binary**: `llvm-git/bin/clang++`

### 2. GCC 15.2.0
- **Why**: Modern C++ stdlib (C++23 support)
- **Provides**:
  - libstdc++ (C++ standard library)
  - libgcc.a (compiler runtime)
  - C++ headers
- **Path**: `nixpkgs#gcc15.cc`

### 3. glibc 2.40-66
- **Why**: C standard library and system headers
- **Provides**:
  - libc.so, libm.so, libpthread.so
  - C headers (`stdio.h`, `limits.h`, etc.)
  - CRT startup objects (`Scrt1.o`, `crti.o`, `crtn.o`)
- **Paths**:
  - Runtime: `nixpkgs#glibc`
  - Headers: `nixpkgs#glibc.dev`

### 4. gcc-14.3.0-lib (stdenv.cc.cc.lib)
- **Why**: Shared GCC runtime with pthread support
- **Provides**: `libgcc_s.so`
- **Path**: `nixpkgs#stdenv.cc.cc.lib`
- **Note**: Historical "s" suffix = "shared" (and pthread-enabled)

### 5. CUDA 13.0.2
- **Why**: CUDA SDK, headers, runtime libraries
- **Provides**:
  - CUDA headers (`cuda_runtime.h`, etc.)
  - libdevice (device code runtime)
  - cudart (CUDA runtime library)
- **Path**: Built via `nix/cuda.nix`

## Integration into cudaStdenv

These flags are integrated into `cudaStdenv` via `stdenvAdapters.addAttrsToDerivation`:

```nix
# Wrap llvm-git's clang with gcc15 for libstdc++
clangGit = final.wrapCCWith {
  cc = final.llvm-git.clang or final.llvm-git;
  useCcForLibs = true;
  gccForLibs = final.gcc15.cc;
};
baseStdenv = final.stdenvAdapters.overrideCC final.gcc15Stdenv clangGit;

# Add CUDA compilation flags
stdenvAdapters.addAttrsToDerivation {
  # gdb-friendly: no strip, full debug symbols, no hardening
  dontStrip = true;
  separateDebugInfo = false;
  hardeningDisable = [ "all" ];
  noAuditTmpdir = true;

  # Compiler flags (driver-level flags + include paths)
  NIX_CFLAGS_COMPILE =
    " -I${final.gcc15.cc}/include/c++/15.2.0"
    + " -I${final.gcc15.cc}/include/c++/15.2.0/x86_64-unknown-linux-gnu"
    + " -I${final.glibc.dev}/include"
    + " --cuda-path=${final.cuda-merged}"
    + " --cuda-gpu-arch=sm_120"
    + " -B${final.glibc}/lib"                                              # CRT objects
    + " -B${final.gcc15.cc}/lib/gcc/x86_64-unknown-linux-gnu/15.2.0"       # GCC runtime objects
    + " -U_FORTIFY_SOURCE -g3 -fno-omit-frame-pointer -fno-limit-debug-info";

  # Linker flags (library search paths)
  NIX_LDFLAGS =
    " -L${final.gcc15.cc}/lib/gcc/x86_64-unknown-linux-gnu/15.2.0"
    + " -L${final.gcc15}/lib"
    + " -L${final.stdenv.cc.cc.lib}/lib"
    + " -L${final.glibc}/lib"              # ← CRITICAL: Needed for libm
    + " -L${final.cuda-merged}/lib64"
    + " -lcudart";

  NIX_CXXSTDLIB_COMPILE = " -std=c++23";
} baseStdenv;
```

**Note**: `-B` flags are compiler driver flags and go in `NIX_CFLAGS_COMPILE`. Putting them in `NIX_LDFLAGS` causes `ld: unrecognized option` errors.

**Verified Working**: Built and tested with `nix build .#cuda-stdenv-test` on 2026-01-05.

## Troubleshooting

### Error: "cannot find libdevice for sm_120"
- **Cause**: `--cuda-path` is wrong or CUDA SDK doesn't have `nvvm/libdevice/libdevice.10.bc`
- **Fix**: Verify `$CUDA/nvvm/libdevice/libdevice.10.bc` exists

### Error: "fatal error: 'climits' file not found"
- **Cause**: Missing C++ stdlib headers during device compilation
- **Fix**: Ensure all three `-I` paths are present (gcc15 C++ headers, arch headers, glibc headers)

### Error: "unable to find library -lm"
- **Cause**: Missing `-L$GLIBC/lib` in library search path
- **Fix**: Add glibc lib directory to `-L` flags

### Warning: "CUDA version is newer than the latest partially supported version 12.9"
- **Cause**: Clang 22 only officially supports up to CUDA 12.9
- **Impact**: Warning only, CUDA 13.0 works
- **Fix**: None needed (cosmetic warning)

## Version Compatibility

| Component | Version | Notes |
|-----------|---------|-------|
| Clang | 22.0.0git | Minimum for SM120, pinned to 2026-01-04 git |
| GCC | 15.2.0 | C++23 stdlib support |
| glibc | 2.40-66 | Current Nix stable |
| CUDA | 13.0.2 | Blackwell support |

## Verified Working Test

**Multi-threaded kernel test (4 blocks × 8 threads):**

```c
__global__ void multithread_kernel(int *out) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    out[idx] = blockIdx.x * 1000 + threadIdx.x;
}

int main() {
    int *d_out, h_out[32];
    cudaMalloc(&d_out, 32 * sizeof(int));
    multithread_kernel<<<4, 8>>>(d_out);
    cudaMemcpy(h_out, d_out, 32 * sizeof(int), cudaMemcpyDeviceToHost);
    // All 32 threads execute correctly
}
```

**Result**: All 32 threads (4 blocks × 8 threads) execute correctly on SM120, each computing correct values.

## Static Linking (BROKEN)

**Attempted static link line:**
```bash
clang++ test.cu \
  --cuda-path=$CUDA --cuda-gpu-arch=sm_120 \
  [same -I/-B/-L flags as dynamic] \
  -static \
  -lcudart_static -lstdc++ -lm -lpthread -lrt -ldl \
  -o test-static
```

**Status**: ❌ Builds but **segfaults at runtime**

**Root Cause**: `libcudart_static.a` calls `dlopen()` to load NVIDIA driver at runtime. Using `-static` flag statically links glibc, but `dlopen()` still requires shared glibc at runtime, causing version conflicts and segfaults.

**Linker Warning**:
```
warning: Using 'dlopen' in statically linked applications requires at
runtime the shared libraries from the glibc version used for linking
```

**Conclusion**: Full static linking is not viable with CUDA runtime due to driver loading requirements. Dynamic linking is the supported approach.

## References

- Investigation: `docs/BLACKWELL-SM120-INVESTIGATION.md`
- LLVM build: `nix/llvm-git.nix`
- cudaStdenv: `flake.nix` (overlay section)
