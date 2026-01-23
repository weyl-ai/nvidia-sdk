# Example NixOS configuration using nvidia-sdk
#
# This example shows how to declaratively configure NVIDIA CUDA on NixOS
# using the nvidia-sdk flake.

{ config, pkgs, inputs, ... }:

{
  imports = [
    # Import the NVIDIA SDK NixOS module
    inputs.nvidia-sdk.nixosModules.default
  ];

  # Apply the overlay to get CUDA packages
  nixpkgs.overlays = [
    inputs.nvidia-sdk.overlays.default
  ];

  # ════════════════════════════════════════════════════════════════════════════
  # NVIDIA SDK Configuration
  # ════════════════════════════════════════════════════════════════════════════

  hardware.nvidia-sdk = {
    enable = true;

    # Driver version (580.119.02 has preset hashes, or specify your own)
    driver.version = "580.119.02";

    # Use open kernel module (required for Blackwell, recommended for Turing+)
    open = true;

    # CUDA version (optional, defaults to latest)
    # cudaVersion = "13.0.2";

    # ──────────────────────────────────────────────────────────────────────────
    # System Integration
    # ──────────────────────────────────────────────────────────────────────────

    # Add CUDA to PATH (nvcc, cuda-gdb, etc.)
    systemPackages = true;

    # Set CUDA_PATH and CUDA_HOME environment variables
    environmentVariables = true;

    # ──────────────────────────────────────────────────────────────────────────
    # FHS Compatibility
    # ──────────────────────────────────────────────────────────────────────────

    # Create /usr/lib/cuda symlink (for tools expecting FHS paths)
    fhs.enable = true;
    fhs.path = "/usr/lib/cuda";

    # ──────────────────────────────────────────────────────────────────────────
    # Services
    # ──────────────────────────────────────────────────────────────────────────

    # nvidia-persistenced for headless/server use
    persistenced = true;

    # Container GPU passthrough (Docker/Podman with CDI)
    container.enable = true;

    # Power management (for laptops)
    powerManagement = false;
  };

  # ════════════════════════════════════════════════════════════════════════════
  # Docker (if using containers)
  # ════════════════════════════════════════════════════════════════════════════

  virtualisation.docker.enable = true;

  # ════════════════════════════════════════════════════════════════════════════
  # Additional CUDA Libraries (optional)
  # ════════════════════════════════════════════════════════════════════════════

  environment.systemPackages = with pkgs; [
    # Deep learning
    cudnn
    nccl
    tensorrt
    cutensor

    # Development
    cuda-samples
    cutlass

    # Profiling (GUI)
    nsight-gui-apps
  ];
}

# ══════════════════════════════════════════════════════════════════════════════
# Usage in flake.nix
# ══════════════════════════════════════════════════════════════════════════════
#
# {
#   inputs = {
#     nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
#     nvidia-sdk.url = "github:weyl-ai/nvidia-sdk";
#   };
#
#   outputs = { nixpkgs, nvidia-sdk, ... }: {
#     nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
#       system = "x86_64-linux";
#       specialArgs = { inherit inputs; };
#       modules = [ ./configuration.nix ];
#     };
#   };
# }
#
# ══════════════════════════════════════════════════════════════════════════════
# Minimal Example
# ══════════════════════════════════════════════════════════════════════════════
#
# hardware.nvidia-sdk = {
#   enable = true;
#   driver.version = "580.119.02";
#   open = true;
# };
#
# That's it! The module handles:
# - Driver installation with correct kernel module
# - OpenGL/Vulkan setup
# - nvidia-persistenced service
# - Modesetting for Wayland
