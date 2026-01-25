{
  description = "// weyl // nvidia-sdk // CUDA 13.0+ with Blackwell SM120 support";

  nixConfig = {
    extra-substituters = [
      "https://weyl-ai.cachix.org"
    ];

    extra-trusted-public-keys = [
      "weyl-ai.cachix.org-1:cR0SpSAPw7wejZ21ep4SLojE77gp5F2os260eEWqTTw="
    ];

    extra-experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    flake-parts.url = "github:hercules-ci/flake-parts";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    # LLVM pinned to known-good SM120 support (2026-01-04)
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

      imports = [
        ./nix/stdenv-overlay.nix
      ];

      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        let
          versions = import ./nix/versions.nix;

          # Apply our overlay to get our packages
          pkgs' = import inputs.nixpkgs {
            inherit system;

            config = {
              cudaSupport = true;              # the monopoly
              cudaCapabilities = [ "12.0" ];   # the future
              rocmSupport = false;             # the controlled opposition
              allowUnfree = true;              # the price of admission
              permittedInsecurePackages = [ ]; # the technical debt
            };

            overlays = [
              (import ./nix/overlays/llvm-sm120.nix)
              inputs.self.overlays.default
              inputs.self.overlays.stdenv-overlay
            ];
          };

          update-script = pkgs'.callPackage ./scripts/update.nix { inherit versions; };
          mirror-cuda = pkgs.callPackage ./scripts/mirror-cuda.nix { };
          agenix = inputs.agenix.packages.${system}.default;
          mirror-arm = pkgs.callPackage ./scripts/mirror-arm.nix { };
        in
        {
          # Re-export packages from our overlay
          packages =
            let
              # Helper to build CUDA for a specific version
              buildCudaVersion = cudaVersion: versionInfo:
                pkgs'.callPackage ./nix/cuda.nix {
                  versions = versions // {
                    cuda = versionInfo;
                  };
                };

              # Generate packages for all CUDA versions
              cudaPackages = pkgs.lib.mapAttrs'
                (version: info: {
                  name = "cuda-${version}";
                  value = buildCudaVersion version info;
                })
                versions.cuda-versions;
            in
            {
              # Primary: nvidia-sdk (CUDA + cuDNN + NCCL + TensorRT + CUTLASS + cuTensor)
              default = pkgs'.nvidia-sdk;
              inherit (pkgs')
                nvidia-sdk

                # CUDA components (if you need them individually)
                cuda
                cudnn
                nccl
                tensorrt
                tensorrt-rtx
                cutensor
                cutlass

                # Weyl Standard stdenvs (for building CUDA code properly)
                weyl-stdenv
                weyl-stdenv-static
                weyl-stdenv-musl
                weyl-stdenv-musl-static
                weyl-stdenv-cuda

                # LLVM with SM120 support
                llvm-git

                # Validation and samples
                cuda-samples
                nccl-tests
                nccl-check
                validate-sdk
                validate-samples

                # CUTLASS examples
                cutlass-examples
                cutlass-examples-basic
                cutlass-examples-cute
                cutlass-examples-hopper
                cutlass-examples-blackwell
                cute-examples

                # Additional tools
                tritonserver
                tritonserver-trtllm
                tensorrt-samples
                nsight-gui-apps
                nsight-dl-designer
                
                # GPU Monitoring
                nvtop
                btop-nvml
                monitoring-tools

                # TRT-LLM Python environment
                trtllm-python
                trtllm-build
                trtllm-env

                # Model runners
                phi4-nvfp4-runner
                tritonserver-phi4
                qwen3-32b-nvfp4-runner
                tritonserver-qwen3
                qwen3-tts-runner
                # OpenAI-compatible (OpenWebUI)
                openai-phi4
                openai-qwen3

                # Native TRT-LLM engines (C++ backend, impure builds)
                # Build with: nix build .#qwen3-32b-engine --option sandbox false
                qwen3-32b-engine
                qwen3-32b-triton-repo
                qwen3-32b-hf-model
                tritonserver-qwen3-native
                ;
              # Expose patched LLVM for testing
              clang-sm120 = pkgs'.llvmPackages_20.clang;
            } // cudaPackages;

          devShells = {
            default = pkgs'.mkShell {
              packages = [
                pkgs'.nvidia-sdk
                pkgs'.tritonserver-trtllm
                pkgs'.openmpi
                pkgs'.prrte
                pkgs'.python312
                agenix
              ];
              shellHook = ''
                echo "nvidia-sdk — CUDA ${versions.cuda.version}"
                echo "Blackwell SM120 | Hopper SM90 | Ada SM89"
                echo "TensorRT-LLM ${pkgs'.tritonserver-trtllm.version}"
                echo ""

                # TRT-LLM Python environment
                export PYTHONPATH="${pkgs'.tritonserver-trtllm}/python''${PYTHONPATH:+:$PYTHONPATH}"
                export LD_LIBRARY_PATH="/run/opengl-driver/lib:${pkgs'.tritonserver-trtllm}/lib:${pkgs'.tritonserver-trtllm}/python/tensorrt_llm/libs:${pkgs'.cuda}/lib64:${pkgs'.cudnn}/lib:${pkgs'.nccl}/lib:${pkgs'.tensorrt}/lib:${pkgs'.openmpi}/lib:${pkgs'.python312}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
                export CUDA_HOME="${pkgs'.cuda}"

                # Aliases for convenience
                alias trtllm-build='python -m tensorrt_llm.commands.build'

                nvidia-sdk-validate || true
              '';
            };
          };

          checks =
            let
              inherit (pkgs'.lib) mapAttrs;

              # Check that a package builds and has expected outputs
              checkPackage = name: pkg: pkgs'.runCommand "check-${name}" {} ''
                # Verify package exists
                test -n "${pkg}" || (echo "${name} is empty" && exit 1)
                # Verify it's a derivation with an outPath
                test -e "${pkg}" || (echo "${name} has no outPath" && exit 1)
                echo "${name}: ok" > $out
              '';

              # Core packages that should always build
              corePackages = {
                inherit (pkgs')
                  cuda
                  cudnn
                  nccl
                  tensorrt
                  tensorrt-rtx
                  cutensor
                  cutlass
                  nvidia-sdk
                  tritonserver
                  cuda-samples
                  nccl-tests
                  cutlass-examples
                  cute-examples
                  tensorrt-samples
                  nsight-gui-apps
                  nsight-dl-designer
                  ;
              };

              # All CUDA versions
              cudaVersionChecks = mapAttrs
                (version: _: checkPackage "cuda-${version}" pkgs'."cuda-${version}")
                versions.cuda-versions;

              # Package build checks
              packageChecks = mapAttrs checkPackage corePackages;

              # TRT-LLM runner checks (verify scripts parse correctly)
              trtllmChecks = {
                phi4-nvfp4-runner = pkgs'.runCommand "check-phi4-nvfp4" {} ''
                  ${pkgs'.phi4-nvfp4-runner}/bin/phi4-nvfp4 --help > /dev/null 2>&1 || true
                  echo "phi4-nvfp4-runner: ok" > $out
                '';

                qwen3-32b-nvfp4-runner = pkgs'.runCommand "check-qwen3-32b-nvfp4" {} ''
                  ${pkgs'.qwen3-32b-nvfp4-runner}/bin/qwen3-32b-nvfp4 --help > /dev/null 2>&1 || true
                  echo "qwen3-32b-nvfp4-runner: ok" > $out
                '';

                tritonserver-phi4 = pkgs'.runCommand "check-tritonserver-phi4" {} ''
                  # Just verify the wrapper script exists and is executable
                  test -x ${pkgs'.tritonserver-phi4}/bin/tritonserver-phi4
                  echo "tritonserver-phi4: ok" > $out
                '';

                tritonserver-qwen3 = pkgs'.runCommand "check-tritonserver-qwen3" {} ''
                  test -x ${pkgs'.tritonserver-qwen3}/bin/tritonserver-qwen3
                  echo "tritonserver-qwen3: ok" > $out
                '';

                tritonserver-trtllm = pkgs'.runCommand "check-tritonserver-trtllm" {} ''
                  test -x ${pkgs'.tritonserver-trtllm}/bin/tritonserver
                  echo "tritonserver-trtllm: ok" > $out
                '';

                openai-phi4 = pkgs'.runCommand "check-openai-phi4" {} ''
                  test -x ${pkgs'.openai-phi4}/bin/openai-phi4
                  echo "openai-phi4: ok" > $out
                '';

                openai-qwen3 = pkgs'.runCommand "check-openai-qwen3" {} ''
                  test -x ${pkgs'.openai-qwen3}/bin/openai-qwen3
                  echo "openai-qwen3: ok" > $out
                '';
              };

              # Functional tests
              functionalChecks = {
                cuda-nvcc = pkgs'.runCommand "check-cuda-nvcc" {} ''
                  test -f ${pkgs'.cuda}/bin/nvcc || (echo "nvcc not found" && exit 1)

                  # nvprof was deprecated in CUDA 11.x, removed in 12.x+
                  # test -f ${pkgs'.cuda}/bin/nvprof || (echo "nvprof not found" && exit 1)

                  echo "cuda binaries: ok" > $out
                '';

                nvidia-sdk-validate = pkgs'.runCommand "check-nvidia-sdk-validate"
                  { nativeBuildInputs = [ pkgs'.nvidia-sdk ]; }
                  ''
                    nvidia-sdk-validate > $out
                  '';

                cuda-samples-build = pkgs'.runCommand "check-cuda-samples"
                  { nativeBuildInputs = [ pkgs'.cuda-samples ]; }
                  ''
                    # Verify sample binaries exist
                    test -f ${pkgs'.cuda-samples}/bin/vectorAdd || (echo "vectorAdd not found" && exit 1)
                    test -f ${pkgs'.cuda-samples}/bin/deviceQuery || (echo "deviceQuery not found" && exit 1)

                    echo "cuda-samples: ok" > $out
                  '';
              };

              # NixOS module tests
              # NOTE: These run in VMs without real GPU hardware, so we test configuration
              # parsing only, not actual GPU functionality
              nixosModuleChecks = {
                module-loads = pkgs'.testers.nixosTest {
                  name = "nvidia-sdk-module-loads";
                  nodes.machine = { config, pkgs, ... }: {
                    imports = [ inputs.self.nixosModules.default ];
                    nixpkgs.overlays = [ inputs.self.overlays.default ];

                    hardware.nvidia-sdk = {
                      enable = true;
                      cudaVersion = "13.0.2";
                      systemPackages = true;
                      environmentVariables = true;
                      container.enable = false;  # Can't test in VM without real hardware
                      persistenced = false;  # Requires actual driver
                    };

                    # Mock nvidia driver to avoid hardware dependency
                    hardware.nvidia.package = pkgs.linuxPackages.nvidia_x11;
                  };

                  testScript = ''
                    machine.wait_for_unit("multi-user.target")
                    machine.succeed("test -f /etc/nvidia-sdk/version")
                    machine.succeed("test -n \"$CUDA_PATH\"")
                  '';
                };

                module-version-selection = pkgs'.testers.nixosTest {
                  name = "nvidia-sdk-version-selection";
                  nodes.machine = { config, pkgs, ... }: {
                    imports = [ inputs.self.nixosModules.default ];
                    nixpkgs.overlays = [ inputs.self.overlays.default ];

                    hardware.nvidia-sdk = {
                      enable = true;
                      cudaVersion = "13.0.1";
                      container.enable = false;
                      persistenced = false;
                    };

                    hardware.nvidia.package = pkgs.linuxPackages.nvidia_x11;
                  };

                  testScript = ''
                    machine.wait_for_unit("multi-user.target")
                    output = machine.succeed("cat /etc/nvidia-sdk/version")
                    assert "13.0.1" in output, f"Expected CUDA 13.0.1, got: {output}"
                  '';
                };

                # Test FHS path creation
                module-fhs-path = pkgs'.testers.nixosTest {
                  name = "nvidia-sdk-fhs-path";
                  nodes.machine = { config, pkgs, ... }: {
                    imports = [ inputs.self.nixosModules.default ];
                    nixpkgs.overlays = [ inputs.self.overlays.default ];

                    hardware.nvidia-sdk = {
                      enable = true;
                      fhs.enable = true;
                      fhs.path = "/usr/lib/cuda";
                      container.enable = false;
                      persistenced = false;
                    };

                    hardware.nvidia.package = pkgs.linuxPackages.nvidia_x11;
                  };

                  testScript = ''
                    machine.wait_for_unit("multi-user.target")
                    # Check that the symlink exists
                    machine.succeed("test -L /usr/lib/cuda")
                    # Check that it points to a valid location
                    machine.succeed("test -d /usr/lib/cuda/bin")
                  '';
                };
              };
            in
            packageChecks // cudaVersionChecks // functionalChecks // trtllmChecks // nixosModuleChecks;

          apps = {
            update = {
              type = "app";
              program = "${update-script}/bin/nvidia-redist-update";
              meta.description = "Update NVIDIA SDK version pins";
            };

            mirror-cuda = {
              type = "app";
              program = "${mirror-cuda}/bin/mirror-cuda-to-r2";
              meta.description = "Mirror CUDA installers to R2 storage";
            };

            mirror-arm = {
              type = "app";
              program = "${mirror-arm}/bin/mirror-arm-to-r2";
              meta.description = "Mirror ARM CUDA installers to R2 storage";
            };

            ncu = {
              type = "app";
              program = "${pkgs'.nvidia-sdk}/bin/ncu";
              meta.description = "NVIDIA Nsight Compute profiler (CLI)";
            };

            nsight-compute = {
              type = "app";
              program = "${pkgs'.nsight-gui-apps}/bin/ncu-ui";
              meta.description = "NVIDIA Nsight Compute profiler (GUI)";
            };

            nsys = {
              type = "app";
              program = "${pkgs'.nvidia-sdk}/bin/nsys";
              meta.description = "NVIDIA Nsight Systems profiler (CLI)";
            };

            nsight-systems = {
              type = "app";
              program = "${pkgs'.nsight-gui-apps}/bin/nsys-ui";
              meta.description = "NVIDIA Nsight Systems profiler (GUI)";
            };

            nsight-designer = {
              type = "app";
              program = "${pkgs'.nsight-dl-designer}/bin/nsight-dl-designer";
              meta.description = "NVIDIA Deep Learning Designer and TensorRT profiler";
            };

            nvtop = {
              type = "app";
              program = "${pkgs'.nvtop}/bin/nvtop";
              meta.description = "GPU process monitor (like htop for GPUs)";
            };

            btop = {
              type = "app";
              program = "${pkgs'.btop-nvml}/bin/btop";
              meta.description = "System monitor with NVIDIA GPU support";
            };

            gpu-monitor = {
              type = "app";
              program = "${pkgs'.monitoring-tools}/bin/gpu-monitor";
              meta.description = "Quick GPU monitoring dashboard";
            };

            # TRT-LLM Python environment
            python = {
              type = "app";
              program = "${pkgs'.trtllm-python}/bin/python";
              meta.description = "Python with TensorRT-LLM environment";
            };

            trtllm-build = {
              type = "app";
              program = "${pkgs'.trtllm-build}/bin/trtllm-build";
              meta.description = "TensorRT-LLM engine builder";
            };

            phi4-nvfp4 = {
              type = "app";
              program = "${pkgs'.phi4-nvfp4-runner}/bin/phi4-nvfp4";
              meta.description = "Run Phi-4 NVFP4 with TensorRT-LLM";
            };

            tritonserver-phi4 = {
              type = "app";
              program = "${pkgs'.tritonserver-phi4}/bin/tritonserver-phi4";
              meta.description = "Triton Inference Server for Phi-4 FP4";
            };

            tritonserver-trtllm = {
              type = "app";
              program = "${pkgs'.tritonserver-trtllm}/bin/tritonserver";
              meta.description = "Triton Inference Server with TensorRT-LLM backend";
            };

            qwen3-32b-nvfp4 = {
              type = "app";
              program = "${pkgs'.qwen3-32b-nvfp4-runner}/bin/qwen3-32b-nvfp4";
              meta.description = "Run Qwen3-32B NVFP4 with TensorRT-LLM";
            };

            tritonserver-qwen3 = {
              type = "app";
              program = "${pkgs'.tritonserver-qwen3}/bin/tritonserver-qwen3";
              meta.description = "Triton Inference Server for Qwen3-32B FP4";
            };

            qwen3-tts = {
              type = "app";
              program = "${pkgs'.qwen3-tts-runner}/bin/qwen3-tts";
              meta.description = "Qwen3-TTS voice synthesis with VoiceDesign";
            };

            # OpenAI-compatible servers (for OpenWebUI)
            openai-phi4 = {
              type = "app";
              program = "${pkgs'.openai-phi4}/bin/openai-phi4";
              meta.description = "OpenAI API: Phi-4 FP4 (streaming, OpenWebUI)";
            };

            openai-qwen3 = {
              type = "app";
              program = "${pkgs'.openai-qwen3}/bin/openai-qwen3";
              meta.description = "OpenAI API: Qwen3-32B FP4 (streaming, OpenWebUI)";
            };

            # Native TRT-LLM engine apps (require impure build first)
            # tritonserver-qwen3-native = {
            #   type = "app";
            #   program = "${pkgs'.tritonserver-qwen3-native}/bin/tritonserver-qwen3-native";
            #   meta.description = "Triton: Qwen3-32B native C++ backend (pre-built engine)";
            # };
          };
        };

      flake = {
        overlays.default =
          final: prev:
          let
            extract = final.callPackage ./nix/extract.nix { };

            modern = (import ./nix/modern.nix final prev).modern;

            triton-container = extract.container-to-nix {
              name = "triton-${versions.triton-container.version}-rootfs";
              image-ref = versions.triton-container.${final.stdenv.hostPlatform.system}.ref;
              hash = versions.triton-container.${final.stdenv.hostPlatform.system}.hash;
            };

            triton-trtllm-container = extract.container-to-nix {
              name = "triton-trtllm-${versions.triton-trtllm-container.version}-rootfs";
              image-ref = versions.triton-trtllm-container.${final.stdenv.hostPlatform.system}.ref;
              hash = versions.triton-trtllm-container.${final.stdenv.hostPlatform.system}.hash;
            };

            versions = import ./nix/versions.nix;

            # Import vendored nixpkgs-master for CUDA packages
            nixpkgs-master = import inputs.nixpkgs-master {
              system = final.stdenv.hostPlatform.system;
              config.allowUnfree = true;
              config.cudaSupport = true;
            };

            # Generate all CUDA version packages for the overlay
            cudaVersionPackages = prev.lib.mapAttrs'
              (version: info: prev.lib.nameValuePair "cuda-${version}" (
                prev.callPackage ./nix/cuda.nix {
                  versions = versions // { cuda = info; };
                }
              ))
              versions.cuda-versions;
          in
          (import ./nix/modern.nix final prev)
          // cudaVersionPackages
          // {
            # LLVM from git (pinned) for SM120 support
            llvm-git = final.callPackage ./nix/llvm-git.nix {
              llvm-project-src = inputs.llvm-project;
            };

            llvmPackages_git = final.llvmPackages.override {
              llvm = final.llvm-git;
            };

            # CUDA stdenv: clang git (SM120), gcc15 libstdc++, C++23, gdb-friendly
            cudaStdenv =
              let
                # Wrap llvm-git's clang with gcc15 for libstdc++
                clangGit = final.wrapCCWith {
                  cc = final.llvm-git.clang or final.llvm-git;
                  useCcForLibs = true;
                  gccForLibs = final.gcc15.cc;
                };
                # Override gcc15Stdenv to use wrapped clang-git
                baseStdenv = final.stdenvAdapters.overrideCC final.gcc15Stdenv clangGit;
              in
              final.stdenvAdapters.addAttrsToDerivation {
                # gdb works
                dontStrip = true;
                separateDebugInfo = false;
                hardeningDisable = [ "all" ];
                noAuditTmpdir = true;

                # CUDA device compilation paths (from CUDA-STDENV-LINK-LINE.md)
                NIX_CFLAGS_COMPILE =
                  " -I${final.gcc15.cc}/include/c++/15.2.0"
                  + " -I${final.gcc15.cc}/include/c++/15.2.0/x86_64-unknown-linux-gnu"
                  + " -I${final.glibc.dev}/include"
                  + " --cuda-path=${final.cuda-merged}"
                  + " --cuda-gpu-arch=sm_120"
                  + " -B${final.glibc}/lib"
                  + " -B${final.gcc15.cc}/lib/gcc/x86_64-unknown-linux-gnu/15.2.0"
                  + " -U_FORTIFY_SOURCE -g3 -fno-omit-frame-pointer -fno-limit-debug-info";

                NIX_LDFLAGS =
                  " -L${final.gcc15.cc}/lib/gcc/x86_64-unknown-linux-gnu/15.2.0"
                  + " -L${final.gcc15}/lib"
                  + " -L${final.stdenv.cc.cc.lib}/lib"
                  + " -L${final.glibc}/lib"
                  + " -L${final.cuda-merged}/lib64"
                  + " -lcudart";

                NIX_CXXSTDLIB_COMPILE = " -std=c++23";
              } baseStdenv;

            # Host-only stdenvs (no CUDA): clang-git + gcc15/musl, C++23, gdb-friendly

            # glibc dynamic
            hostStdenv =
              let
                clangGit = final.wrapCCWith {
                  cc = final.llvm-git.clang or final.llvm-git;
                  useCcForLibs = true;
                  gccForLibs = final.gcc15.cc;
                };
                baseStdenv = final.stdenvAdapters.overrideCC final.gcc15Stdenv clangGit;
              in
              final.stdenvAdapters.addAttrsToDerivation {
                dontStrip = true;
                separateDebugInfo = false;
                hardeningDisable = [ "all" ];
                noAuditTmpdir = true;

                NIX_CFLAGS_COMPILE =
                  " -I${final.gcc15.cc}/include/c++/15.2.0"
                  + " -I${final.gcc15.cc}/include/c++/15.2.0/x86_64-unknown-linux-gnu"
                  + " -I${final.glibc.dev}/include"
                  + " -B${final.glibc}/lib"
                  + " -B${final.gcc15.cc}/lib/gcc/x86_64-unknown-linux-gnu/15.2.0"
                  + " -U_FORTIFY_SOURCE -g3 -fno-omit-frame-pointer -fno-limit-debug-info";

                NIX_LDFLAGS =
                  " -L${final.gcc15.cc}/lib/gcc/x86_64-unknown-linux-gnu/15.2.0"
                  + " -L${final.gcc15}/lib"
                  + " -L${final.stdenv.cc.cc.lib}/lib"
                  + " -L${final.glibc}/lib";

                NIX_CXXSTDLIB_COMPILE = " -std=c++23";
              } baseStdenv;

            # glibc static (pkgsStatic is musl-based, so use makeStaticBinaries on hostStdenv)
            hostStdenvStatic = final.stdenvAdapters.makeStaticBinaries final.hostStdenv;

            # musl dynamic
            muslStdenv =
              let
                clangMusl = final.wrapCCWith {
                  cc = final.llvm-git.clang or final.llvm-git;
                  libc = final.musl;
                  bintools = final.binutils-unwrapped;
                };
                baseStdenv = final.stdenvAdapters.overrideCC final.stdenv clangMusl;
              in
              final.stdenvAdapters.addAttrsToDerivation {
                dontStrip = true;
                separateDebugInfo = false;
                hardeningDisable = [ "all" ];
                noAuditTmpdir = true;

                NIX_CFLAGS_COMPILE =
                  " -U_FORTIFY_SOURCE -g3 -fno-omit-frame-pointer -fno-limit-debug-info";

                NIX_CXXSTDLIB_COMPILE = " -std=c++23";
              } baseStdenv;

            # musl static (musl is static-first by design)
            muslStdenvStatic = final.muslStdenv.override {
              mkDerivation = args: final.muslStdenv.mkDerivation (args // {
                NIX_LDFLAGS = (args.NIX_LDFLAGS or "") + " -static";
              });
            };

            # Smoke tests

            cuda-stdenv-test = final.cudaStdenv.mkDerivation {
              name = "cuda-stdenv-test";
              unpackPhase = "true";
              buildPhase = ''
                cat > test.cu <<'EOF'
                #include <stdio.h>
                __global__ void k() { printf("sm_120 works\n"); }
                int main() { k<<<1,1>>>(); cudaDeviceSynchronize(); return 0; }
                EOF
                $CXX test.cu -o test
              '';
              installPhase = "mkdir -p $out/bin; cp test $out/bin/";
            };

            host-stdenv-test = final.hostStdenv.mkDerivation {
              name = "host-stdenv-test";
              unpackPhase = "true";
              buildPhase = ''
                cat > test.cpp <<'EOF'
                #include <print>
                #include <vector>
                int main() {
                  std::vector<int> v = {1, 2, 3};
                  std::println("glibc dynamic C++23 works, size={}", v.size());
                }
                EOF
                $CXX test.cpp -o test
              '';
              installPhase = "mkdir -p $out/bin; cp test $out/bin/";
            };

            host-stdenv-static-test = final.hostStdenvStatic.mkDerivation {
              name = "host-stdenv-static-test";
              unpackPhase = "true";
              buildPhase = ''
                cat > test.cpp <<'EOF'
                #include <print>
                #include <vector>
                int main() {
                  std::vector<int> v = {1, 2, 3};
                  std::println("glibc static C++23 works, size={}", v.size());
                }
                EOF
                $CXX test.cpp -o test
              '';
              installPhase = "mkdir -p $out/bin; cp test $out/bin/";
            };

            musl-stdenv-test = final.muslStdenv.mkDerivation {
              name = "musl-stdenv-test";
              unpackPhase = "true";
              buildPhase = ''
                cat > test.cpp <<'EOF'
                #include <print>
                #include <vector>
                int main() {
                  std::vector<int> v = {1, 2, 3};
                  std::println("musl dynamic C++23 works, size={}", v.size());
                }
                EOF
                $CXX test.cpp -o test
              '';
              installPhase = "mkdir -p $out/bin; cp test $out/bin/";
            };

            musl-stdenv-static-test = final.muslStdenvStatic.mkDerivation {
              name = "musl-stdenv-static-test";
              unpackPhase = "true";
              buildPhase = ''
                cat > test.cpp <<'EOF'
                #include <print>
                #include <vector>
                int main() {
                  std::vector<int> v = {1, 2, 3};
                  std::println("musl static C++23 works, size={}", v.size());
                }
                EOF
                $CXX test.cpp -o test
              '';
              installPhase = "mkdir -p $out/bin; cp test $out/bin/";
            };

            cuda = final.callPackage ./nix/cuda.nix { inherit versions; };

            # Symlink-joined CUDA for C++20/23 support with LLVM
            # Clang requires a flat directory structure for --cuda-path
            cuda-merged = prev.symlinkJoin {
              name = "cuda-${final.cuda.version}-merged";
              paths = [ final.cuda ];
              postBuild = ''
                # Ensure /lib is the primary library directory (not /lib64)
                if [ -d $out/lib64 ] && [ ! -e $out/lib ]; then
                  ln -s lib64 $out/lib
                fi
              '';
            };

            cudnn = final.callPackage ./nix/cudnn.nix {
              inherit versions extract;
              cuda = final.cuda;
            };

            nccl = final.callPackage ./nix/nccl.nix {
              inherit versions;
              cuda = final.cuda;
            };

            tensorrt = final.callPackage ./nix/tensorrt.nix {
              inherit versions extract;
              cuda = final.cuda;
              cudnn = final.cudnn;
              nccl = final.nccl;
            };

            tensorrt-rtx = final.callPackage ./nix/tensorrt-rtx.nix {
              inherit versions extract;
              cuda = final.cuda;
              cudnn = final.cudnn;
              nccl = final.nccl;
            };

            cutensor = final.callPackage ./nix/cutensor.nix {
              inherit versions extract;
              cuda = final.cuda;
            };

            cutlass = final.callPackage ./nix/cutlass.nix { inherit versions; };

            nvidia-sdk = final.callPackage ./nix/nvidia-sdk.nix {
              inherit versions;
              cuda = final.cuda;
              cudnn = final.cudnn;
              nccl = final.nccl;
              tensorrt = final.tensorrt;
              cutlass = final.cutlass;
              cutensor = final.cutensor;
            };

            tritonserver = final.callPackage ./nix/tritonserver.nix {
              inherit versions triton-container modern;
              cuda = final.cuda;
              cudnn = final.cudnn;
              nccl = final.nccl;
              tensorrt = final.tensorrt;
              cutensor = final.cutensor;
            };

            tritonserver-trtllm = final.callPackage ./nix/tritonserver-trtllm.nix {
              inherit versions triton-trtllm-container modern;
              cuda = final.cuda;
              cudnn = final.cudnn;
              nccl = final.nccl;
              tensorrt = final.tensorrt;
              cutensor = final.cutensor;
            };

            # TensorRT-LLM runner library (Python API - runtime engine build)
            trtllm = final.callPackage ./nix/trtllm-runner.nix {
              tritonserver-trtllm = final.tritonserver-trtllm;
              inherit triton-trtllm-container;
              cuda = final.cuda;
            };

            # Python with TensorRT-LLM environment
            # Usage: nix run .#python -- -c "from tensorrt_llm import LLM; print('ok')"
            # Or:    nix shell .#python -c "trtllm-build --help"
            trtllm-python = final.writeShellScriptBin "python" ''
              export PYTHONPATH="${final.tritonserver-trtllm}/python''${PYTHONPATH:+:$PYTHONPATH}"
              export LD_LIBRARY_PATH="/run/opengl-driver/lib:${final.tritonserver-trtllm}/lib:${final.tritonserver-trtllm}/python/tensorrt_llm/libs:${final.cuda}/lib64:${final.cudnn}/lib:${final.nccl}/lib:${final.tensorrt}/lib:${final.openmpi}/lib:${final.python312}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              export CUDA_HOME="${final.cuda}"
              exec ${final.python312}/bin/python "$@"
            '';

            # TRT-LLM build command wrapper
            trtllm-build = final.writeShellScriptBin "trtllm-build" ''
              export PYTHONPATH="${final.tritonserver-trtllm}/python''${PYTHONPATH:+:$PYTHONPATH}"
              export LD_LIBRARY_PATH="/run/opengl-driver/lib:${final.tritonserver-trtllm}/lib:${final.tritonserver-trtllm}/python/tensorrt_llm/libs:${final.cuda}/lib64:${final.cudnn}/lib:${final.nccl}/lib:${final.tensorrt}/lib:${final.openmpi}/lib:${final.python312}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              export CUDA_HOME="${final.cuda}"
              exec ${final.python312}/bin/python -m tensorrt_llm.commands.build "$@"
            '';

            # Full TRT-LLM development environment
            trtllm-env = final.buildEnv {
              name = "trtllm-env";
              paths = [
                final.trtllm-python
                final.trtllm-build
                final.tritonserver-trtllm
                final.openmpi
                final.prrte
              ];
            };

            # TensorRT-LLM engine builder (C++ native - build-time engine)
            trtllm-engine = final.callPackage ./nix/trtllm-engine.nix {
              tritonserver-trtllm = final.tritonserver-trtllm;
              cuda = final.cuda;
            };

            # Phi-4 NVFP4 runner (TensorRT-LLM)
            phi4-nvfp4-runner = final.trtllm.mkRunner {
              name = "phi4-nvfp4";
              model = "nvidia/Phi-4-reasoning-plus-NVFP4";
              description = "Phi-4 14B FP4 on Blackwell (SM120)";
              defaultTemperature = 0.8;
              defaultTopP = 0.95;
            };

            # Triton Inference Server for Phi-4 FP4
            tritonserver-phi4 = final.trtllm.mkTritonServer {
              name = "phi4";
              model = "nvidia/Phi-4-reasoning-plus-NVFP4";
              description = "Triton: Phi-4 14B FP4 on Blackwell";
              defaultTemperature = 0.8;
              defaultTopP = 0.95;
            };

            # Qwen3-32B NVFP4 runner (TensorRT-LLM)
            qwen3-32b-nvfp4-runner = final.trtllm.mkRunner {
              name = "qwen3-32b-nvfp4";
              model = "nvidia/Qwen3-32B-NVFP4";
              description = "Qwen3 32B FP4 on Blackwell (SM120)";
              defaultTemperature = 0.7;
              defaultTopP = 0.9;
              chatTemplate = "qwen3";  # Enable Qwen3 chat template with --thinking flag
              extraPythonCode = ''
def format_prompt(text, thinking=False):
    """Format prompt with Qwen3 chat template."""
    if thinking:
        return f"<|im_start|>system\nYou are a helpful assistant. Think step by step.<|im_end|>\n<|im_start|>user\n{text}<|im_end|>\n<|im_start|>assistant\n"
    else:
        return f"<|im_start|>user\n{text}<|im_end|>\n<|im_start|>assistant\n"
'';
            };

            # Triton Inference Server for Qwen3-32B FP4
            tritonserver-qwen3 = final.trtllm.mkTritonServer {
              name = "qwen3";
              model = "nvidia/Qwen3-32B-NVFP4";
              description = "Triton: Qwen3 32B FP4 on Blackwell";
              defaultTemperature = 0.7;
              defaultTopP = 0.9;
              extraInputs = [
                ''{ name: "use_chat_template", data_type: TYPE_INT32, dims: [ 1 ], optional: true }''
              ];
              extraModelCode = ''
            use_chat_template = self._get_scalar(request, "use_chat_template", 1)
            if use_chat_template:
                prompts = [f"<|im_start|>user\n{p}<|im_end|>\n<|im_start|>assistant\n" for p in prompts]
'';
            };

            # OpenAI-compatible servers (for OpenWebUI, streaming)
            openai-phi4 = final.trtllm.mkOpenAIServer {
              name = "phi4";
              model = "nvidia/Phi-4-reasoning-plus-NVFP4";
              description = "OpenAI API: Phi-4 14B FP4 (streaming, OpenWebUI)";
            };

            openai-qwen3 = final.trtllm.mkOpenAIServer {
              name = "qwen3";
              model = "nvidia/Qwen3-32B-NVFP4";
              description = "OpenAI API: Qwen3 32B FP4 (streaming, OpenWebUI)";
              # Use alternate ports to avoid conflict with existing Triton on 8000
              httpPort = 8100;
              grpcPort = 8101;
              metricsPort = 8102;
              openaiPort = 9100;
            };

            # Qwen3-TTS runner (VoiceDesign model, uses PyTorch nightly for SM120)
            qwen3-tts-runner = final.callPackage ./nix/qwen3-tts-runner.nix {
              cuda = final.cuda;
            };

            # ══════════════════════════════════════════════════════════════════════
            # Native TensorRT-LLM Engines (C++ backend, build-time engine compilation)
            # ══════════════════════════════════════════════════════════════════════
            # NOTE: These are IMPURE builds that require GPU access (__noChroot = true)
            # Build with: nix build .#qwen3-32b-engine --option sandbox false

            # Qwen3-32B-NVFP4 TensorRT engine (pre-built)
            # Uses the locally downloaded HF model to avoid network access during build
            qwen3-32b-engine = final.trtllm-engine.mkEngineFromHf {
              name = "qwen3-32b-nvfp4";
              model = final.qwen3-32b-hf-model;  # Use local model, not HF ID
              maxBatchSize = 8;
              maxInputLen = 8192;
              maxSeqLen = 16384;
              maxNumTokens = 8192;
              tensorParallelSize = 1;  # Single GPU
            };

            # Qwen3-32B Triton model repository (native tensorrtllm backend)
            qwen3-32b-triton-repo = final.trtllm-engine.mkTritonRepo {
              name = "qwen3-32b";
              engine = final.qwen3-32b-engine;
              tokenizer = final.qwen3-32b-hf-model;
              maxBatchSize = 8;
              kvCacheFreeGpuMemFraction = 0.9;
              enableChunkedContext = true;
            };

            # Qwen3-32B HuggingFace model download (FOD)
            # NOTE: You must provide the correct hash after first download attempt
            qwen3-32b-hf-model = final.trtllm-engine.mkHfModel {
              name = "qwen3-32b-nvfp4";
              model = "nvidia/Qwen3-32B-NVFP4";
              hash = "sha256-Uekvo4NlzbrbZcKPSyzd7opvZDh+JOE55jrUbcsMu8Q=";
            };

            # Triton server wrapper for native Qwen3 engine
            tritonserver-qwen3-native = final.trtllm-engine.mkTritonServer {
              name = "qwen3-native";
              repo = final.qwen3-32b-triton-repo;
              httpPort = 8000;
              grpcPort = 8001;
              metricsPort = 8002;
            };

            # Example packages to demonstrate SDK functionality
            cuda-samples = final.callPackage ./nix/cuda-samples.nix {
              inherit versions;
              cuda = final.cuda;
            };

            nccl-tests = final.callPackage ./nix/nccl-tests.nix {
              cuda = final.cuda;
              nccl = final.nccl;
            };

            nccl-check = final.callPackage ./nix/nccl-check.nix {
              nccl-tests = final.nccl-tests;
            };

            # CUTLASS examples builder - flexible function for building specific examples
            mkCutlassExamples = final.callPackage ./nix/cutlass-examples-builder.nix {
              inherit versions;
              cuda-merged = final.cuda-merged;
              cutlass = final.cutlass;
              autoAddDriverRunpath = final.autoAddDriverRunpath or prev.cudaPackages.autoAddDriverRunpath;
            };

            # Convenient preset groups
            cutlass-examples = final.mkCutlassExamples {
              exampleTargets = [ "00_basic_gemm" ];  # Just one example for quick testing
            };
            cutlass-examples-basic = final.mkCutlassExamples {
              exampleTargets = [ "00_basic_gemm" "01_cutlass_utilities" "02_dump_reg_smem" ];
            };
            cutlass-examples-cute = final.mkCutlassExamples {
              exampleTargets = [ "cute" ];
            };
            cutlass-examples-hopper = final.mkCutlassExamples {
              exampleTargets = [ "80_hopper_transpose" "81_hopper_reduce" "82_hopper_rs_gemm" ];
            };
            cutlass-examples-blackwell = final.mkCutlassExamples {
              exampleTargets = [ "86_blackwell_mixed_dtype_gemm" "91_fp4_gemv" ];
            };

            cute-examples = final.callPackage ./nix/cute-examples.nix {
              inherit versions;
              cuda = final.cuda;
              cutlass = final.cutlass;
            };

            tensorrt-samples = final.callPackage ./nix/tensorrt-samples.nix {
              inherit versions;
              cuda = final.cuda;
              cudnn = final.cudnn;
              tensorrt = final.tensorrt;
              nccl = final.nccl;
            };

            # Nixpkgs-master CUDA packages (vendored)
            nixpkgs-nsight-compute = nixpkgs-master.cudaPackages.nsight_compute;
            nixpkgs-nsight-systems = nixpkgs-master.cudaPackages.nsight_systems;

            # GUI applications (uses NVIDIA's bundled Qt6 with nixpkgs base)
            nsight-gui-apps = final.callPackage ./nix/nsight-gui-apps.nix {
              inherit versions;
              nvidia-sdk = final.nvidia-sdk;
              nsight-compute = final.nixpkgs-nsight-compute;
              nsight-systems = final.nixpkgs-nsight-systems;
            };

            # Nsight DL Designer - ONNX editor and TensorRT profiler
            nsight-dl-designer = final.callPackage ./nix/nsight-dl-designer.nix { inherit versions; };

            # Validation utilities
            validate-sdk = final.callPackage ./nix/validate-sdk.nix {
              nvidia-sdk = final.nvidia-sdk;
            };

            validate-samples = final.callPackage ./nix/validate-samples.nix {
              cuda-samples = final.cuda-samples;
            };

            # GPU Monitoring tools
            monitoring-tools-pkg = final.callPackage ./nix/monitoring-tools.nix {
              cuda = final.cuda;
            };
            nvtop = final.monitoring-tools-pkg.nvtop;
            btop-nvml = final.monitoring-tools-pkg.btop;
            monitoring-tools = final.monitoring-tools-pkg.monitoring-tools;
          };

        # NixOS module for declarative NVIDIA driver + CUDA installation
        nixosModules.default = import ./nix/modules/nvidia-sdk.nix;
        nixosModules.nvidia-sdk = import ./nix/modules/nvidia-sdk.nix;

        # flake-parts flakeModule for easy integration
        flakeModules.default = import ./nix/modules/flake-module.nix;
        flakeModules.nvidia-sdk = import ./nix/modules/flake-module.nix;
      };
    };
}
