# nix/versions/driver/default.nix — NVIDIA Driver Versions
#
# NVIDIA proprietary and open kernel module driver versions.
# NOTE: These hashes must be updated with real values before use.

{ lib }:

{
  driver = {
    version = "590.44.01";

    x86_64-linux = {
      url = "https://us.download.nvidia.com/XFree86/Linux-x86_64/590.44.01/NVIDIA-Linux-x86_64-590.44.01.run";
      hash = "sha256-VbkVaKwElaazojfxkHnz/nN/5olk13ezkw/EQjhKPms=";
    };

    aarch64-linux = {
      # Note: NVIDIA doesn't always provide aarch64 drivers at the same URL pattern
      # Check https://developer.nvidia.com/cuda-downloads for the correct URL
      url = "https://developer.download.nvidia.com/compute/cuda/13.1.0/local_installers/cuda_13.1.0_590.44.01_linux_sbsa.run";
      # TODO: Fetch actual hash when URL is confirmed
      hash = lib.warn "aarch64 driver hash is a placeholder - update when URL confirmed!" "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };

    # Open kernel module hashes (Turing+ GPUs)
    # Note: Open kernel modules are distributed separately
    # Check https://github.com/NVIDIA/open-gpu-kernel-modules for releases
    open = {
      x86_64-linux = {
        # TODO: Open kernel module 590.44.01 hash needs to be fetched
        # The open kernel module is typically at:
        # https://github.com/NVIDIA/open-gpu-kernel-modules/releases/tag/590.44.01
        hash = lib.warn "Open kernel module hash is a placeholder - fetch from GitHub releases!" "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      };
      aarch64-linux = {
        # TODO: Open kernel module hash for aarch64
        hash = lib.warn "Open kernel module hash is a placeholder - fetch from GitHub releases!" "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      };
    };
  };
}
