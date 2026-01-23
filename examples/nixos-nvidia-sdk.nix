# Example NixOS configuration using nvidia-sdk module
#
# This demonstrates the Weyl Standard approach:
# - Exact driver version control
# - Selective CUDA exposure (no global pollution)
# - Explicit program wrapping

{ inputs, ... }:
{
  imports = [
    inputs.libmodern-nvidia-sdk.nixosModules.default
  ];

  nixpkgs.overlays = [
    inputs.libmodern-nvidia-sdk.overlays.default
  ];

  hardware.nvidia-sdk = {
    enable = true;

    # ──────────────────────────────────────────────────────────────────────
    # Exact driver version (Blackwell 580.95.05)
    # ──────────────────────────────────────────────────────────────────────

    driver = {
      version = "580.95.05";
      sha256_64bit = "sha256-hJ7w746EK5gGss3p8RwTA9VPGpp2lGfk5dlhsv4Rgqc=";
      sha256_aarch64 = "sha256-F2wmUEaRrpR1Vz0TQSwVK4Fv13f3J9NJLtBe4UP2f14=";
      openSha256 = "sha256-RFwDGQOi9jVngVONCOB5m/IYKZIeGEle7h0+0yGnBEI=";
      settingsSha256 = "sha256-F2wmUEaRrpR1Vz0TQSwVK4Fv13f3J9NJLtBe4UP2f14=";
      persistencedSha256 = "sha256-qKnpl4WceGyWUvVMI+55jRZbRvvgQw9dhlTSzHm7W1w=";
    };

    # ──────────────────────────────────────────────────────────────────────
    # CUDA version (defaults to latest if null)
    # ──────────────────────────────────────────────────────────────────────

    cudaVersion = "13.0.2";  # or null for latest

    # ──────────────────────────────────────────────────────────────────────
    # Exposure policy
    # ──────────────────────────────────────────────────────────────────────
    #
    # "none"     — No global exposure (recommended)
    # "system"   — Add to systemPackages (traditional, not recommended)
    # "selective" — envfs-based (future)

    expose = "none";

    # ──────────────────────────────────────────────────────────────────────
    # Wrap specific programs with CUDA access
    # ──────────────────────────────────────────────────────────────────────

    wrapPrograms = [ pkgs.python3 ];

    # ──────────────────────────────────────────────────────────────────────
    # Hardware config
    # ──────────────────────────────────────────────────────────────────────

    opengl.enable = true;
    openKernelModule = false;  # Use proprietary for now
    powerManagement.enable = false;
  };
}
