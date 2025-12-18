{
  description = "nvidia-redist — NVIDIA SDK for intel and grace";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      versions = import ./nix/versions.nix;

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      pkgsFor = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ self.overlays.default ];
      };

    in {
      overlays.default = final: prev:
        let
          extract = final.callPackage ./nix/extract.nix {};

          triton-container = extract.container-to-nix {
            name = "triton-${versions.triton-container.version}-rootfs";
            image-ref = versions.triton-container.${final.stdenv.hostPlatform.system}.ref;
            hash = versions.triton-container.${final.stdenv.hostPlatform.system}.hash;
          };

        in {
          cuda = final.callPackage ./nix/cuda.nix { inherit versions; };
          cudnn = final.callPackage ./nix/cudnn.nix { inherit versions extract; cuda = final.cuda; };
          nccl = final.callPackage ./nix/nccl.nix { inherit versions triton-container; cuda = final.cuda; };
          tensorrt = final.callPackage ./nix/tensorrt.nix {
            inherit versions extract;
            cuda = final.cuda;
            cudnn = final.cudnn;
            nccl = final.nccl;
          };
          cutensor = final.callPackage ./nix/cutensor.nix { inherit versions extract; cuda = final.cuda; };
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
            inherit versions triton-container;
            cuda = final.cuda;
            cudnn = final.cudnn;
            nccl = final.nccl;
            tensorrt = final.tensorrt;
            cutensor = final.cutensor;
          };
        };

      packages = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          default = pkgs.nvidia-sdk;
          inherit (pkgs) cuda cudnn nccl tensorrt cutensor cutlass nvidia-sdk tritonserver;
        }
      );

      devShells = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          default = pkgs.mkShell {
            packages = [ pkgs.nvidia-sdk ];
            shellHook = ''
              echo "nvidia-redist — CUDA ${versions.cuda.version}"
              nvidia-sdk-validate || true
            '';
          };
        }
      );

      checks = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          cuda = pkgs.runCommand "check-cuda" {} ''
            test -f ${pkgs.cuda}/bin/nvcc && echo "nvcc ok" > $out
          '';
          nvidia-sdk = pkgs.runCommand "check-nvidia-sdk" { nativeBuildInputs = [ pkgs.nvidia-sdk ]; } ''
            nvidia-sdk-validate > $out
          '';
        }
      );

      apps = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          update-script = pkgs.callPackage ./scripts/update.nix { inherit versions; };
        in {
          update = {
            type = "app";
            program = "${update-script}/bin/nvidia-redist-update";
          };
        }
      );

      lib = { inherit versions; };
    };
}
