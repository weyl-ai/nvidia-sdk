# Simple test to verify the NixOS module evaluates correctly
# Run with: nix eval --impure --expr 'import ./tests/nixos-module-test.nix {}'

{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
}:

let
  # Minimal NixOS config evaluation
  eval = lib.evalModules {
    modules = [
      # Import our module
      ../nix/nixos-module.nix

      # Minimal mock NixOS config
      {
        options = {
          boot.kernelPackages = lib.mkOption {
            type = lib.types.attrs;
            default = pkgs.linuxPackages;
          };
          services.xserver.videoDrivers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          environment.systemPackages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
          };
          environment.variables = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
          };
          environment.sessionVariables = lib.mkOption {
            type = lib.types.attrsOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
            default = { };
          };
          environment.etc = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
          };
          hardware.opengl = lib.mkOption {
            type = lib.types.submodule { };
            default = { };
          };
          hardware.nvidia = lib.mkOption {
            type = lib.types.submodule { };
            default = { };
          };
          nixpkgs.config = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          assertions = lib.mkOption {
            type = lib.types.listOf lib.types.unspecified;
            default = [ ];
          };
          warnings = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
        };

        config = {
          # Mock nixpkgs with our overlay applied
          _module.args.pkgs = pkgs // {
            cuda = pkgs.hello; # Mock CUDA package
            "cuda-13.0.2" = pkgs.hello;
            "cuda-13.1" = pkgs.hello;
          };

          # Enable our CUDA module
          hardware.nvidia.cuda = {
            enable = true;
            version = "13.0.2";
          };
        };
      }
    ];
  };

  config = eval.config;
in
{
  # Test that the module evaluates without errors
  success = true;

  # Test that CUDA is enabled
  cudaEnabled = config.hardware.nvidia.cuda.enable;

  # Test that the correct version is selected
  cudaVersion = config.hardware.nvidia.cuda.version;

  # Test that NVIDIA driver is in videoDrivers
  hasNvidiaDriver = lib.elem "nvidia" config.services.xserver.videoDrivers;

  # Test that OpenGL is enabled
  openglEnabled = config.hardware.opengl.enable or false;

  # Test that CUDA is in system packages
  hasCudaPackage = lib.any (pkg: pkg.name or "" == "hello") config.environment.systemPackages;

  # Summary
  summary = {
    inherit (config.hardware.nvidia.cuda) enable version;
    videoDrivers = config.services.xserver.videoDrivers;
    cudaPackages = builtins.length config.environment.systemPackages;
  };
}
