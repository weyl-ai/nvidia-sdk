# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Weyl AI
{
  description = "NVIDIA CUDA SDK for NixOS — CUDA 13.1 + Blackwell SM120";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    # LLVM pinned to known-good SM120 support
    llvm-project = {
      url = "github:llvm/llvm-project/bb1f220d534b0f6d80bea36662f5188ff11c2e54";
      flake = false;
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        { config, system, ... }:
        let
          versions = import ./nix/versions.nix;

          # Import nixpkgs with unfree + CUDA config
          pkgs = import inputs.nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              cudaSupport = true;
            };
          };

          # ════════════════════════════════════════════════════════════════════
          # PLATFORM (shared via nix/lib/platform.nix)
          # ════════════════════════════════════════════════════════════════════

          inherit (pkgs) lib stdenv;
          platform = import ./nix/lib/platform.nix {
            inherit lib stdenv;
            inherit (pkgs) gcc15;
          };

          # ════════════════════════════════════════════════════════════════════
          # LLVM-GIT (SM120 support)
          # ════════════════════════════════════════════════════════════════════

          llvm-git = pkgs.callPackage ./nix/pkgs/llvm-git.nix {
            llvm-project-src = inputs.llvm-project;
          };

          # ════════════════════════════════════════════════════════════════════
          # CUDA STDENV — The One True Toolchain
          # ════════════════════════════════════════════════════════════════════

          cudaStdenv = platform.mkCudaStdenv {
            inherit (pkgs) wrapCCWith stdenvAdapters glibc;
            inherit llvm-git cuda-merged;
            gcc15Stdenv = pkgs.gcc15Stdenv;
            ccLib = stdenv.cc.cc.lib;
            gcc15Pkg = pkgs.gcc15;
          };

          # ════════════════════════════════════════════════════════════════════
          # MODERN PRIMITIVES
          # ════════════════════════════════════════════════════════════════════

          modern = (import ./nix/modern.nix pkgs pkgs).modern;

          # ════════════════════════════════════════════════════════════════════
          # CUDA COMPONENTS
          # ════════════════════════════════════════════════════════════════════

          cuda = pkgs.callPackage ./nix/pkgs/cuda.nix { inherit versions; };

          cuda-merged = pkgs.symlinkJoin {
            name = "cuda-${cuda.version}-merged";
            paths = [ cuda ];
            postBuild = ''
              if [ -d $out/lib64 ] && [ ! -e $out/lib ]; then
                ln -s lib64 $out/lib
              fi
            '';
          };

          cudnn = pkgs.callPackage ./nix/pkgs/cudnn.nix {
            inherit versions;
            extract = modern;
            cuda = cuda;
          };

          nccl = pkgs.callPackage ./nix/pkgs/nccl.nix {
            inherit versions;
            cuda = cuda;
          };

          tensorrt = pkgs.callPackage ./nix/pkgs/tensorrt.nix {
            inherit versions;
            extract = modern;
            cuda = cuda;
            cudnn = cudnn;
            nccl = nccl;
          };

          cutensor = pkgs.callPackage ./nix/pkgs/cutensor.nix {
            inherit versions;
            extract = modern;
            cuda = cuda;
          };

          cutlass = pkgs.callPackage ./nix/pkgs/cutlass.nix {
            inherit versions;
            cuda = cuda;
          };

          nvidia-sdk = pkgs.callPackage ./nix/pkgs/nvidia-sdk.nix {
            inherit
              versions
              cuda
              cudnn
              nccl
              tensorrt
              cutlass
              cutensor
              ;
          };

          # ════════════════════════════════════════════════════════════════════
          # VALIDATION & SAMPLES
          # ════════════════════════════════════════════════════════════════════

          cuda-samples = pkgs.callPackage ./nix/pkgs/cuda-samples.nix {
            inherit versions;
            cuda = cuda;
          };

          nccl-tests = pkgs.callPackage ./nix/pkgs/nccl-tests.nix {
            cuda = cuda;
            nccl = nccl;
          };

          validate-sdk = pkgs.callPackage ./nix/pkgs/validate-sdk.nix {
            nvidia-sdk = nvidia-sdk;
          };

          # ════════════════════════════════════════════════════════════════════
          # MONITORING
          # ════════════════════════════════════════════════════════════════════

          monitoring = pkgs.callPackage ./nix/pkgs/monitoring-tools.nix {
            cuda = cuda;
          };

        in
        {
          packages = {
            default = nvidia-sdk;
            inherit
              nvidia-sdk
              cuda
              cudnn
              nccl
              tensorrt
              cutensor
              cutlass
              cuda-merged
              cuda-samples
              nccl-tests
              validate-sdk
              llvm-git
              cudaStdenv
              ;

            nvtop = monitoring.nvtop;
            btop = monitoring.btop;
          };

          devShells.default = pkgs.mkShell {
            packages = [ nvidia-sdk ];

            shellHook = ''
              echo "nvidia-sdk — CUDA ${versions.cuda.version} — NGC ${versions.ngc.version}"
              echo ""
              export LD_LIBRARY_PATH="${nvidia-sdk}/lib64:/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              export CUDA_PATH="${nvidia-sdk}"
              export CUDA_HOME="${nvidia-sdk}"
            '';
          };

          checks = {
            # ── SDK structure ──────────────────────────────────────────────
            sdk-structure =
              pkgs.runCommand "check-sdk-structure"
                {
                  nativeBuildInputs = [
                    nvidia-sdk
                    pkgs.pkg-config
                  ];
                }
                ''
                  echo "=== SDK structure check ==="

                  # setup-hook must set CUDA_PATH
                  test -n "$CUDA_PATH" || (echo "FAIL: CUDA_PATH not set by setup-hook" && exit 1)
                  echo "ok: CUDA_PATH=$CUDA_PATH"

                  # Headers
                  test -d "$CUDA_PATH/include" || (echo "FAIL: include/ missing" && exit 1)
                  for hdr in cuda.h cudnn.h nccl.h NvInfer.h cutensor.h; do
                    test -f "$CUDA_PATH/include/$hdr" || (echo "FAIL: $hdr missing" && exit 1)
                  done
                  echo "ok: headers present"

                  # Core libraries
                  for lib in cudart cublas cufft curand cusolver cusparse nvrtc cudnn nccl nvinfer cutensor; do
                    ls "$CUDA_PATH/lib64/lib$lib"*.so* >/dev/null 2>&1 || (echo "FAIL: lib$lib.so missing" && exit 1)
                  done
                  echo "ok: core libraries present"

                  # Key binaries
                  for bin in nvcc ptxas fatbinary nvlink; do
                    test -x "$CUDA_PATH/bin/$bin" || (echo "FAIL: $bin missing" && exit 1)
                  done
                  echo "ok: core binaries present"

                  # pkg-config
                  pkg-config --validate nvidia-sdk || (echo "FAIL: nvidia-sdk.pc invalid" && exit 1)
                  echo "ok: pkg-config valid"

                  # version.json
                  test -f "$CUDA_PATH/version.json" || (echo "FAIL: version.json missing" && exit 1)
                  echo "ok: version.json present"

                  # validate script
                  test -x "$CUDA_PATH/bin/nvidia-sdk-validate" || (echo "FAIL: nvidia-sdk-validate missing" && exit 1)
                  echo "ok: nvidia-sdk-validate present"

                  echo "=== SDK structure: PASS ===" > $out
                '';

            # ── Version consistency ────────────────────────────────────────
            version-consistency =
              pkgs.runCommand "check-version-consistency"
                {
                  nativeBuildInputs = [
                    nvidia-sdk
                    pkgs.jq
                  ];
                }
                ''
                  echo "=== Version consistency check ==="

                  json="$CUDA_PATH/version.json"
                  test -f "$json" || (echo "FAIL: version.json missing" && exit 1)

                  check() {
                    local key="$1" expected="$2"
                    actual=$(${pkgs.jq}/bin/jq -r ".$key" "$json")
                    if [ "$actual" != "$expected" ]; then
                      echo "FAIL: $key: expected '$expected', got '$actual'"
                      exit 1
                    fi
                    echo "ok: $key=$actual"
                  }

                  check cuda     "${versions.cuda.version}"
                  check cudnn    "${versions.cudnn.version}"
                  check nccl     "${versions.nccl.version}"
                  check tensorrt "${versions.tensorrt.version}"
                  check cutlass  "${versions.cutlass.version}"
                  check cutensor "${versions.cutensor.version}"

                  echo "=== Version consistency: PASS ===" > $out
                '';

            # ── LLVM NVPTX target ─────────────────────────────────────────
            llvm-nvptx = pkgs.runCommand "check-llvm-nvptx" { } ''
              ${llvm-git}/bin/clang --print-targets | ${pkgs.gnugrep}/bin/grep -iq nvptx \
                || (echo "FAIL: NVPTX target missing from LLVM" && exit 1)
              echo "ok: LLVM has NVPTX target" > $out
            '';

            # ── Individual package structure ──────────────────────────────
            component-structure = pkgs.runCommand "check-component-structure" { } ''
              echo "=== Component structure check ==="

              # cuDNN
              test -f "${cudnn}/lib/libcudnn.so" || test -d "${cudnn}/lib" \
                || (echo "FAIL: cudnn lib/ missing" && exit 1)
              test -f "${cudnn}/include/cudnn.h" \
                || (echo "FAIL: cudnn headers missing" && exit 1)
              echo "ok: cudnn"

              # NCCL
              test -f "${nccl}/lib/libnccl.so" \
                || (echo "FAIL: nccl lib missing" && exit 1)
              test -f "${nccl}/include/nccl.h" \
                || (echo "FAIL: nccl headers missing" && exit 1)
              echo "ok: nccl"

              # TensorRT
              test -f "${tensorrt}/lib/libnvinfer.so" \
                || (echo "FAIL: tensorrt lib missing" && exit 1)
              test -f "${tensorrt}/include/NvInfer.h" \
                || (echo "FAIL: tensorrt headers missing" && exit 1)
              echo "ok: tensorrt"

              # cuTensor
              test -f "${cutensor}/lib/libcutensor.so" || ls "${cutensor}/lib"/libcutensor*.so* >/dev/null 2>&1 \
                || (echo "FAIL: cutensor lib missing" && exit 1)
              echo "ok: cutensor"

              # CUTLASS (header-only)
              test -d "${cutlass}/include/cutlass" \
                || (echo "FAIL: cutlass headers missing" && exit 1)
              echo "ok: cutlass"

              echo "=== Component structure: PASS ===" > $out
            '';

            # ── Setup-hook env vars ───────────────────────────────────────
            setup-hook = pkgs.runCommand "check-setup-hook" { nativeBuildInputs = [ nvidia-sdk ]; } ''
              echo "=== Setup-hook check ==="
              for var in CUDA_PATH CUDA_HOME CUDNN_HOME TENSORRT_HOME; do
                eval "val=\$$var"
                test -n "$val" || (echo "FAIL: $var not set" && exit 1)
                echo "ok: $var=$val"
              done
              echo "=== Setup-hook: PASS ===" > $out
            '';

            # ── Platform arch consistency ─────────────────────────────────
            platform-arch = pkgs.runCommand "check-platform-arch" { } ''
              echo "=== Platform arch check ==="
              arch="${platform.cudaArch}"
              case "$arch" in
                sm_100|sm_120|sm_121)
                  echo "ok: cudaArch=$arch"
                  ;;
                *)
                  echo "FAIL: unexpected cudaArch=$arch"
                  exit 1
                  ;;
              esac
              echo "=== Platform arch: PASS ===" > $out
            '';
          };

          apps = {
            # Monitoring
            nvtop = {
              type = "app";
              program = "${monitoring.nvtop}/bin/nvtop";
              meta.description = "GPU process monitor";
            };

            btop = {
              type = "app";
              program = "${monitoring.btop}/bin/btop";
              meta.description = "System monitor with GPU support";
            };
          };
        };

      flake = {
        overlays.default =
          final: prev:
          let
            versions = import ./nix/versions.nix;
            modern = (import ./nix/modern.nix final prev).modern;

            inherit (final) lib stdenv;
            platform = import ./nix/lib/platform.nix {
              inherit lib stdenv;
              inherit (final) gcc15;
            };
          in
          {
            inherit modern;

            llvm-git = final.callPackage ./nix/pkgs/llvm-git.nix {
              llvm-project-src = inputs.llvm-project;
            };

            cuda = final.callPackage ./nix/pkgs/cuda.nix { inherit versions; };

            cuda-merged = prev.symlinkJoin {
              name = "cuda-${final.cuda.version}-merged";
              paths = [ final.cuda ];
              postBuild = ''
                if [ -d $out/lib64 ] && [ ! -e $out/lib ]; then
                  ln -s lib64 $out/lib
                fi
              '';
            };

            cudaStdenv = platform.mkCudaStdenv {
              inherit (final) wrapCCWith stdenvAdapters glibc;
              llvm-git = final.llvm-git;
              cuda-merged = final.cuda-merged;
              gcc15Stdenv = final.gcc15Stdenv;
              ccLib = final.stdenv.cc.cc.lib;
              gcc15Pkg = final.gcc15;
            };

            cudnn = final.callPackage ./nix/pkgs/cudnn.nix {
              inherit versions;
              extract = modern;
              cuda = final.cuda;
            };

            nccl = final.callPackage ./nix/pkgs/nccl.nix {
              inherit versions;
              cuda = final.cuda;
            };

            tensorrt = final.callPackage ./nix/pkgs/tensorrt.nix {
              inherit versions;
              extract = modern;
              cuda = final.cuda;
              cudnn = final.cudnn;
              nccl = final.nccl;
            };

            cutensor = final.callPackage ./nix/pkgs/cutensor.nix {
              inherit versions;
              extract = modern;
              cuda = final.cuda;
            };

            cutlass = final.callPackage ./nix/pkgs/cutlass.nix {
              inherit versions;
              cuda = final.cuda;
            };

            nvidia-sdk = final.callPackage ./nix/pkgs/nvidia-sdk.nix {
              inherit versions;
              cuda = final.cuda;
              cudnn = final.cudnn;
              nccl = final.nccl;
              tensorrt = final.tensorrt;
              cutlass = final.cutlass;
              cutensor = final.cutensor;
            };

            cuda-samples = final.callPackage ./nix/pkgs/cuda-samples.nix {
              inherit versions;
              cuda = final.cuda;
            };

            nccl-tests = final.callPackage ./nix/pkgs/nccl-tests.nix {
              cuda = final.cuda;
              nccl = final.nccl;
            };

            validate-sdk = final.callPackage ./nix/pkgs/validate-sdk.nix {
              nvidia-sdk = final.nvidia-sdk;
            };

            monitoring-tools = final.callPackage ./nix/pkgs/monitoring-tools.nix {
              cuda = final.cuda;
            };

            nvtop = final.monitoring-tools.nvtop;
            btop-nvml = final.monitoring-tools.btop;
          };

        nixosModules.default = import ./nix/modules/nvidia-sdk.nix;
        nixosModules.nvidia-sdk = import ./nix/modules/nvidia-sdk.nix;
      };
    };
}
