# Example configuration for driver 580.x series
# Works with 580.119.02, 580.126.09, and other 580.x drivers
#
# Usage: Import this in your NixOS configuration

{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.libmodern-nvidia-sdk.nixosModules.default
  ];

  nixpkgs.overlays = [
    inputs.libmodern-nvidia-sdk.overlays.default
  ];

  nixpkgs.config.allowUnfree = true;

  hardware.nvidia-sdk = {
    enable = true;
    
    # CUDA 13.0.2 requires driver >= 580.95.05
    # Compatible with: 580.119.02, 580.126.09, any 580.x or newer
    cudaVersion = "13.0.2";
    
    # Let NixOS manage the driver version automatically
    # This will use whatever driver nixpkgs provides (stable/beta/latest)
    # No need to specify exact hashes
    
    # Expose CUDA to specific programs only (recommended for production)
    expose = "none";
    wrapPrograms = [
      pkgs.python3
      # Add other programs that need CUDA here
    ];
    
    # Or expose system-wide (simpler for development)
    # expose = "system";
    
    # Hardware configuration
    opengl.enable = true;
    openKernelModule = true;  # You're using open kernel module (580.119.02 Open)
    powerManagement.enable = false;
    
    # GPU monitoring tools (enabled by default)
    # Includes: nvtop, btop (with NVML), nvidia-smi (from driver)
    monitoring.enable = true;
    
    # Container runtime support (enabled by default)
    # Automatically configures Docker/Podman for GPU access via CDI
    container.enable = true;
    
    # NVIDIA Persistenced (enabled by default)
    # Keeps GPU initialized for headless/server workloads
    # Essential for containers and compute-only setups
    nvidiaPersistenced = true;
  };

  # Verify your driver version matches
  # Run: cat /proc/driver/nvidia/version
  # Should show: NVRM version: NVIDIA UNIX Open Kernel Module for x86_64 580.xxx.xx
}
