# flake-module.nix — flake-parts module for nvidia-sdk
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# This is a flake-parts flakeModule that exports the nvidia-sdk NixOS module.
#
# Usage in a flake-parts flake:
#
#   inputs.nvidia-sdk.url = "github:weyl-ai/nvidia-sdk";
#
#   outputs = inputs: flake-parts.lib.mkFlake { inherit inputs; } {
#     imports = [ inputs.nvidia-sdk.flakeModules.default ];
#
#     # The module automatically:
#     # - Exports nixosModules.nvidia-sdk
#     # - Exports overlays.nvidia-sdk
#     # - Provides perSystem packages
#   };
#
# Then in your NixOS configuration:
#
#   nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
#     modules = [
#       self.nixosModules.nvidia-sdk
#       {
#         nixpkgs.overlays = [ self.overlays.nvidia-sdk ];
#         hardware.nvidia-sdk.enable = true;
#       }
#     ];
#   };
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{ self, lib, flake-parts-lib, ... }:

let
  inherit (flake-parts-lib) mkPerSystemOption;
in
{
  # ══════════════════════════════════════════════════════════════════════════
  # FLAKE OUTPUTS
  # ══════════════════════════════════════════════════════════════════════════

  flake = {
    # Export the NixOS module
    nixosModules.nvidia-sdk = ./nvidia-sdk.nix;
    nixosModules.default = ./nvidia-sdk.nix;
  };

  # ══════════════════════════════════════════════════════════════════════════
  # PER-SYSTEM OPTIONS (for consumers who want to customize)
  # ══════════════════════════════════════════════════════════════════════════

  options.perSystem = mkPerSystemOption ({ config, pkgs, ... }: {
    options.nvidia-sdk = {
      # Allow consumers to access the cuda package directly
      cudaPackage = lib.mkOption {
        type = lib.types.package;
        default = pkgs.nvidia-sdk or pkgs.cuda or (throw "nvidia-sdk overlay not applied");
        defaultText = lib.literalExpression "pkgs.nvidia-sdk";
        description = "The CUDA/nvidia-sdk package to use";
        readOnly = true;
      };
    };
  });
}
