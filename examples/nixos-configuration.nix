# Example NixOS configuration using libmodern-nvidia-sdk
#
# This example shows how to declaratively configure NVIDIA CUDA on NixOS
# using the libmodern-nvidia-sdk flake.

{ config, pkgs, inputs, ... }:

{
  imports = [
    # Import the CUDA module from libmodern-nvidia-sdk
    inputs.libmodern-nvidia-sdk.nixosModules.default
  ];

  # Apply the overlay to get CUDA packages
  nixpkgs.overlays = [
    inputs.libmodern-nvidia-sdk.overlays.default
  ];

  # Configure NVIDIA SDK
  hardware.nvidia-sdk = {
    enable = true;

    # Choose your CUDA version
    # Available: "12.9.1", "13.0.0", "13.0.1", "13.0.2", "13.1"
    cudaVersion = "13.0.2";

    # Optional: specify a custom CUDA package
    # cudaPackage = pkgs.cuda; # defaults to the version specified above

    # Add CUDA to system packages (default: true)
    addToSystemPackages = true;

    # Set CUDA as default runtime (adds to PATH, LD_LIBRARY_PATH)
    setDefaultRuntime = true;

    # Enable OpenGL support (required for most CUDA apps)
    opengl.enable = true;
  };

  # The module automatically:
  # - Enables the NVIDIA driver
  # - Configures OpenGL/Vulkan support
  # - Sets up environment variables
  # - Adds CUDA to system packages
  # - Validates driver version compatibility

  # Additional NVIDIA configuration (optional)
  hardware.nvidia = {
    # Use open-source kernel module (Turing+)
    open = false;

    # Enable nvidia-settings menu
    nvidiaSettings = true;

    # Enable modesetting (required for Wayland)
    modesetting.enable = true;

    # Power management
    powerManagement = {
      enable = false; # Set to true for laptops
      finegrained = false;
    };
  };

  # Optional: Add additional NVIDIA SDK components
  environment.systemPackages = with pkgs; [
    # Core CUDA toolkit (automatically included if addToSystemPackages = true)
    # cuda

    # Deep learning libraries
    cudnn
    nccl
    tensorrt
    cutensor

    # Development tools
    cuda-samples
    nccl-tests

    # Profiling tools (GUI apps)
    nsight-gui-apps

    # CUTLASS for high-performance GEMM
    cutlass
    cutlass-examples
    cute-examples
  ];

  # Optional: Enable Docker with NVIDIA container runtime
  virtualisation.docker = {
    enable = true;
    enableNvidia = true; # Requires hardware.nvidia-sdk.enable = true
  };

  # Optional: Per-user CUDA installation (instead of system-wide)
  # Set addToSystemPackages = false and use:
  # users.users.youruser.packages = [ pkgs.cuda ];
}

# Usage in flake.nix:
#
# {
#   inputs = {
#     nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
#     libmodern-nvidia-sdk.url = "github:yourorg/libmodern-nvidia-sdk";
#   };
#
#   outputs = { nixpkgs, libmodern-nvidia-sdk, ... }: {
#     nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
#       system = "x86_64-linux";
#       specialArgs = { inputs = { inherit libmodern-nvidia-sdk; }; };
#       modules = [
#         ./configuration.nix
#       ];
#     };
#   };
# }
