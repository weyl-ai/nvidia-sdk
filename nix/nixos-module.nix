{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.nvidia-sdk;
  versions = import ./versions.nix;

  # Get all available CUDA versions
  availableVersions = lib.attrNames versions.cuda-versions;

  # Get the selected CUDA version config
  selectedVersion = versions.cuda-versions.${cfg.cudaVersion} or (throw "CUDA version ${cfg.cudaVersion} not found");

  # NVIDIA driver package from nixpkgs
  # We override the version to match our CUDA version's driver
  nvidiaDriverPackage = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs (old: {
    version = selectedVersion.driver;
    # Note: The actual driver installation from .run file would need to be handled
    # For now, we rely on nixpkgs' driver matching or user having compatible driver
  });
in
{
  options.hardware.nvidia-sdk = {
    enable = lib.mkEnableOption "NVIDIA SDK (CUDA toolkit + cuDNN/NCCL/TensorRT)";

    cudaVersion = lib.mkOption {
      type = lib.types.enum availableVersions;
      default = versions.cuda.version;
      description = ''
        NVIDIA CUDA version to install. Available versions:
        ${lib.concatStringsSep ", " availableVersions}

        Each CUDA version requires a specific minimum driver version:
        ${lib.concatStringsSep "\n        " (
          lib.mapAttrsToList (v: info: "- ${v}: driver ${info.driver}") versions.cuda-versions
        )}
      '';
      example = "13.0.2";
    };

    cudaPackage = lib.mkOption {
      type = lib.types.package;
      default =
        if cfg.cudaVersion == versions.cuda.version then
          pkgs.cuda or (throw "cuda package not found - ensure the libmodern-nvidia-sdk overlay is applied")
        else
          pkgs."cuda-${cfg.cudaVersion}" or (throw "CUDA ${cfg.cudaVersion} package not found in pkgs - ensure the overlay is applied");
      defaultText = lib.literalExpression "pkgs.cuda (or pkgs.\"cuda-\${cudaVersion}\" if non-default)";
      description = ''
        CUDA package to use. Automatically selects the package matching the 'cudaVersion' option.
        You can override this to use a custom CUDA package.
      '';
    };

    addToSystemPackages = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to add CUDA toolkit to systemPackages. Disable if you want per-user installation.";
    };

    setDefaultRuntime = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to set CUDA as the default runtime (adds to PATH, LD_LIBRARY_PATH).";
    };

    opengl.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable OpenGL support (required for most CUDA applications).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable NVIDIA driver
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      # Use open-source kernel module (Turing+)
      open = lib.mkDefault false;

      # Enable nvidia-settings menu
      nvidiaSettings = lib.mkDefault true;

      # Driver package - users should ensure they have the right driver installed
      # or we rely on nixpkgs' driver which may not exactly match
      package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.stable;

      # Enable modesetting (required for Wayland)
      modesetting.enable = lib.mkDefault true;

      # Power management
      powerManagement = {
        enable = lib.mkDefault false;
        finegrained = lib.mkDefault false;
      };
    };

    # OpenGL/Graphics support
    hardware.graphics = lib.mkIf cfg.opengl.enable {
      enable = true;
      enable32Bit = lib.mkDefault true;
    };

    # Add CUDA to system packages
    environment.systemPackages = lib.mkIf cfg.addToSystemPackages [
      cfg.cudaPackage
    ];

    # Set up environment variables for CUDA runtime
    environment.variables = lib.mkIf cfg.setDefaultRuntime {
      CUDA_PATH = "${cfg.cudaPackage}";
      CUDA_HOME = "${cfg.cudaPackage}";
      CUDA_TOOLKIT_ROOT = "${cfg.cudaPackage}";
    };

    # Add CUDA libraries to the system path
    environment.sessionVariables = lib.mkIf cfg.setDefaultRuntime {
      LD_LIBRARY_PATH = lib.mkAfter [ "${cfg.cudaPackage}/lib" ];
    };

    # Expose metadata about the selected version
    environment.etc."nvidia-sdk-version".text = ''
      CUDA Version: ${selectedVersion.version}
      Required Driver: ${selectedVersion.driver}
      Installed via: libmodern-nvidia-sdk
    '';

    # Assertions to help users
    assertions = [
      # Temporarily disabled to debug configuration issues
      # {
      #   assertion = config.services.xserver.videoDrivers == [ "nvidia" ] || lib.elem "nvidia" config.services.xserver.videoDrivers;
      #   message = ''
      #     hardware.nvidia-sdk: NVIDIA driver not enabled in videoDrivers.
      #
      #     The NVIDIA SDK requires the proprietary NVIDIA kernel driver.
      #     You have enabled hardware.nvidia-sdk but the NVIDIA driver is not configured.
      #
      #     Add to your configuration:
      #       services.xserver.videoDrivers = [ "nvidia" ];
      #
      #     Or if you already have videoDrivers configured:
      #       services.xserver.videoDrivers = [ "nvidia" ] ++ config.services.xserver.videoDrivers;
      #
      #     Current videoDrivers: ${builtins.toString config.services.xserver.videoDrivers}
      #   '';
      # }
      {
        assertion = cfg.cudaPackage != null;
        message = ''
          hardware.nvidia-sdk: CUDA package is null.

          The libmodern-nvidia-sdk overlay must be applied to nixpkgs for
          CUDA packages to be available.

          Add to your configuration (usually in flake.nix or configuration.nix):
            nixpkgs.overlays = [ inputs.libmodern-nvidia-sdk.overlays.default ];

          Example flake.nix:
            nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              modules = [
                {
                  nixpkgs.overlays = [ inputs.libmodern-nvidia-sdk.overlays.default ];
                  imports = [ inputs.libmodern-nvidia-sdk.nixosModules.default ];
                  hardware.nvidia-sdk.enable = true;
                }
              ];
            };
        '';
      }
    ];

    # Warnings
    warnings =
      let
        driverVersion = config.boot.kernelPackages.nvidiaPackages.stable.version or "unknown";
        requiredDriver = selectedVersion.driver;
        # Newer drivers are backward compatible, only warn if driver is older
        driverIsOlder = driverVersion != "unknown" &&
                       builtins.compareVersions driverVersion requiredDriver < 0;
      in
      lib.optional driverIsOlder ''
        CUDA ${cfg.cudaVersion} requires driver ${requiredDriver} or newer, but nixpkgs provides ${driverVersion}.

        You may need to:
        1. Update nixpkgs to get a newer driver
        2. Manually install driver ${requiredDriver} or newer

        Current driver: ${driverVersion}
        Minimum required: ${requiredDriver}
      '';
  };
}
