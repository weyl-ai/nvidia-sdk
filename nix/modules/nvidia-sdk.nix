# nvidia-sdk.nix — NixOS Module for NVIDIA GPU + CUDA
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# A NixOS module for deploying NVIDIA CUDA with exact driver control.
#
# Usage (in your flake):
#
#   inputs.nvidia-sdk.url = "github:weyl-ai/nvidia-sdk";
#
#   nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
#     modules = [
#       inputs.nvidia-sdk.nixosModules.default
#       {
#         nixpkgs.overlays = [ inputs.nvidia-sdk.overlays.default ];
#         hardware.nvidia-sdk = {
#           enable = true;
#           driver.version = "580.119.02";  # or use preset
#           open = true;  # Blackwell requires open kernel module
#         };
#       }
#     ];
#   };
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.nvidia-sdk;

  # ════════════════════════════════════════════════════════════════════════════
  # DRIVER VERSION PRESETS
  # ════════════════════════════════════════════════════════════════════════════
  #
  # Known-good driver versions with all required hashes.
  # Use: hardware.nvidia-sdk.driver.version = "580.119.02";

  driverPresets = {
    # CUDA 13.0.2+ / Blackwell SM120 support
    "580.119.02" = {
      sha256_64bit = "sha256-gCD139PuiK7no4mQ0MPSr+VHUemhcLqerdfqZwE47Nc=";
      sha256_aarch64 = "sha256-qp/N1hl6S+97qB8fDMeMcrpx8KXZjwKBJsOj0QESQ9E=";
      openSha256 = "sha256-l3IQDoopOt0n0+Ig+Ee3AOcFCGJXhbH1Q1nh1TEAHTE=";
      settingsSha256 = "sha256-sI/ly6gNaUw0QZFWWkMbrkSstzf0hvcdSaogTUoTecI=";
      persistencedSha256 = "sha256-j74m3tAYON/q8WLU9Xioo3CkOSXfo1CwGmDx/ot0uUo=";
    };

    # CUDA 13.0.0-13.0.1
    "575.51.02" = {
      sha256_64bit = "sha256-XhB7Zg6miRRmfLbbx3l3AIu7YHhemG5lXqkjNhi8f0A=";
      sha256_aarch64 = "sha256-3BCWP8lLG9bvbRBnVIPO3U9x7viwqR5J2+lCvZzeJYs=";
      openSha256 = "sha256-ImtTr/s2Aahgz7lqLEJrcGrCh7bXmQwvdKF99Jq7adw=";
      settingsSha256 = "sha256-3BCWP8lLG9bvbRBnVIPO3U9x7viwqR5J2+lCvZzeJYs=";
      persistencedSha256 = "sha256-3BCWP8lLG9bvbRBnVIPO3U9x7viwqR5J2+lCvZzeJYs=";
    };
  };

  # ════════════════════════════════════════════════════════════════════════════
  # DRIVER CONFIGURATION
  # ════════════════════════════════════════════════════════════════════════════

  # Resolve driver: explicit version > preset > nixpkgs stable
  driverHashes =
    if cfg.driver.sha256_64bit != "" then {
      # User provided explicit hashes
      inherit (cfg.driver) sha256_64bit sha256_aarch64 openSha256 settingsSha256 persistencedSha256;
    } else if cfg.driver.version != null && driverPresets ? ${cfg.driver.version} then
      # Use preset hashes
      driverPresets.${cfg.driver.version}
    else
      # No hashes available
      null;

  nvidiaDriver =
    if cfg.driver.version != null && driverHashes != null then
      config.boot.kernelPackages.nvidiaPackages.mkDriver {
        inherit (cfg.driver) version;
        inherit (driverHashes) sha256_64bit sha256_aarch64 openSha256 settingsSha256 persistencedSha256;
      }
    else if cfg.driver.version != null then
      throw ''
        nvidia-sdk: Driver version ${cfg.driver.version} specified but no hashes provided.

        Either:
        1. Use a known preset version: ${lib.concatStringsSep ", " (lib.attrNames driverPresets)}
        2. Provide all hashes manually:
           hardware.nvidia-sdk.driver = {
             version = "${cfg.driver.version}";
             sha256_64bit = "sha256-...";
             sha256_aarch64 = "sha256-...";
             openSha256 = "sha256-...";
             settingsSha256 = "sha256-...";
             persistencedSha256 = "sha256-...";
           };
      ''
    else
      # Fallback to nixpkgs stable
      config.boot.kernelPackages.nvidiaPackages.stable;

  # ════════════════════════════════════════════════════════════════════════════
  # CUDA PACKAGE SELECTION
  # ════════════════════════════════════════════════════════════════════════════

  cudaPackage =
    if cfg.cudaVersion != null then
      pkgs."cuda-${cfg.cudaVersion}" or (
        throw "CUDA ${cfg.cudaVersion} not available. Run: nix flake show github:weyl-ai/nvidia-sdk"
      )
    else
      pkgs.nvidia-sdk or (
        throw "nvidia-sdk package not found. Ensure overlay is applied: nixpkgs.overlays = [ inputs.nvidia-sdk.overlays.default ];"
      );

in
{
  # ══════════════════════════════════════════════════════════════════════════
  # OPTIONS
  # ══════════════════════════════════════════════════════════════════════════

  options.hardware.nvidia-sdk = {
    enable = lib.mkEnableOption "NVIDIA SDK (CUDA + driver with exact version control)";

    # ──────────────────────────────────────────────────────────────────────────
    # Driver Configuration
    # ──────────────────────────────────────────────────────────────────────────

    driver = {
      version = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "580.119.02";
        description = ''
          NVIDIA driver version. Known presets with hashes included:
          ${lib.concatStringsSep ", " (lib.attrNames driverPresets)}

          For other versions, provide all sha256 hashes manually.
          If null, uses nixpkgs' stable driver.
        '';
      };

      sha256_64bit = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SHA256 hash for x86_64 driver (optional if using preset)";
      };

      sha256_aarch64 = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SHA256 hash for aarch64 driver (optional if using preset)";
      };

      openSha256 = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SHA256 hash for open kernel module (optional if using preset)";
      };

      settingsSha256 = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SHA256 hash for nvidia-settings (optional if using preset)";
      };

      persistencedSha256 = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SHA256 hash for nvidia-persistenced (optional if using preset)";
      };
    };

    # ──────────────────────────────────────────────────────────────────────────
    # CUDA Configuration
    # ──────────────────────────────────────────────────────────────────────────

    cudaVersion = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "13.0.2";
      description = ''
        CUDA version to use. If null, uses the default nvidia-sdk (latest).
        Available versions: nix flake show github:weyl-ai/nvidia-sdk
      '';
    };

    # ──────────────────────────────────────────────────────────────────────────
    # Kernel Module
    # ──────────────────────────────────────────────────────────────────────────

    open = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Use open-source kernel module.
        Required for Blackwell (SM120). Recommended for Turing+ (SM75+).
        Set to false only for legacy GPUs (Maxwell, Pascal).
      '';
    };

    # ──────────────────────────────────────────────────────────────────────────
    # FHS Compatibility
    # ──────────────────────────────────────────────────────────────────────────

    fhs.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Create FHS-compatible paths for CUDA.
        Creates /usr/lib/cuda symlink pointing to the CUDA installation.
        
        Note: For proper FHS compatibility with tools that expect /usr/lib/cuda,
        consider using envfs for selective exposure instead.
      '';
    };

    fhs.path = lib.mkOption {
      type = lib.types.str;
      default = "/usr/lib/cuda";
      description = "FHS path where CUDA should be exposed (symlink target)";
    };

    # ──────────────────────────────────────────────────────────────────────────
    # System Integration
    # ──────────────────────────────────────────────────────────────────────────

    systemPackages = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Add CUDA toolkit to environment.systemPackages.
        Makes nvcc, cuda-gdb, etc. available system-wide.
      '';
    };

    environmentVariables = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Set CUDA_PATH and CUDA_HOME environment variables system-wide.
        Only applies if systemPackages is also enabled.
      '';
    };

    # ──────────────────────────────────────────────────────────────────────────
    # Services
    # ──────────────────────────────────────────────────────────────────────────

    persistenced = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable nvidia-persistenced daemon.
        Keeps GPU initialized for headless/server workloads.
        Essential for: containers, faster CUDA init, compute workloads.
      '';
    };

    # ──────────────────────────────────────────────────────────────────────────
    # Container Runtime
    # ──────────────────────────────────────────────────────────────────────────

    container.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable NVIDIA Container Toolkit for Docker/Podman GPU access.
        Uses CDI (Container Device Interface) for GPU passthrough.
      '';
    };

    docker.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Docker with GPU support.
        Sets up Docker daemon with CDI enabled for GPU passthrough.
      '';
    };

    docker.rootless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable rootless Docker with GPU support.
        Requires container.enable = true.
      '';
    };

    # ──────────────────────────────────────────────────────────────────────────
    # Power Management
    # ──────────────────────────────────────────────────────────────────────────

    powerManagement = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable NVIDIA power management (for laptops)";
    };
  };

  # ══════════════════════════════════════════════════════════════════════════
  # IMPLEMENTATION
  # ══════════════════════════════════════════════════════════════════════════

  config = lib.mkIf cfg.enable {

    # ──────────────────────────────────────────────────────────────────────────
    # Driver Setup
    # ──────────────────────────────────────────────────────────────────────────

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      package = nvidiaDriver;
      open = cfg.open;
      nvidiaSettings = lib.mkDefault true;
      modesetting.enable = lib.mkDefault true;

      powerManagement = {
        enable = cfg.powerManagement;
        finegrained = lib.mkDefault false;
      };
    };

    # ──────────────────────────────────────────────────────────────────────────
    # OpenGL/Graphics
    # ──────────────────────────────────────────────────────────────────────────

    hardware.graphics = {
      enable = true;
      enable32Bit = lib.mkDefault true;
    };

    # ──────────────────────────────────────────────────────────────────────────
    # CUDA System Packages
    # ──────────────────────────────────────────────────────────────────────────

    environment.systemPackages = lib.mkIf cfg.systemPackages [ cudaPackage ];

    environment.variables = lib.mkIf (cfg.systemPackages && cfg.environmentVariables) {
      CUDA_PATH = "${cudaPackage}";
      CUDA_HOME = "${cudaPackage}";
    };

    # ──────────────────────────────────────────────────────────────────────────
    # FHS Compatibility (/usr/lib/cuda)
    # ──────────────────────────────────────────────────────────────────────────

    # Create /usr/lib/cuda symlink via systemd-tmpfiles
    systemd.tmpfiles.rules = lib.mkIf cfg.fhs.enable [
      "L+ ${cfg.fhs.path} - - - - ${cudaPackage}"
    ];

    # ──────────────────────────────────────────────────────────────────────────
    # NVIDIA Persistenced
    # ──────────────────────────────────────────────────────────────────────────

    systemd.services.nvidia-persistenced = lib.mkIf cfg.persistenced {
      description = "NVIDIA Persistence Daemon";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "forking";
        Restart = "always";
        PIDFile = "/run/nvidia-persistenced/nvidia-persistenced.pid";
        ExecStart = "${nvidiaDriver.persistenced}/bin/nvidia-persistenced --user root --persistence-mode --verbose";
        ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /run/nvidia-persistenced";
        RuntimeDirectory = "nvidia-persistenced";
      };
    };

    # ──────────────────────────────────────────────────────────────────────────
    # Container Runtime
    # ──────────────────────────────────────────────────────────────────────────

    hardware.nvidia-container-toolkit.enable = lib.mkIf cfg.container.enable true;

    # Docker configuration
    virtualisation.docker = lib.mkMerge [
      # Root daemon
      (lib.mkIf cfg.docker.enable {
        enable = true;
        enableOnBoot = lib.mkDefault true;
        autoPrune.enable = lib.mkDefault true;
        daemon.settings.features.cdi = lib.mkIf cfg.container.enable true;
      })
      # Rootless daemon
      (lib.mkIf cfg.docker.rootless {
        rootless = {
          enable = true;
          setSocketVariable = true;
          daemon.settings.features.cdi = lib.mkIf cfg.container.enable true;
        };
      })
    ];

    virtualisation.podman = lib.mkIf (cfg.container.enable && config.virtualisation.podman.enable) {
      extraPackages = [ pkgs.nvidia-container-toolkit ];
    };

    # ──────────────────────────────────────────────────────────────────────────
    # Metadata
    # ──────────────────────────────────────────────────────────────────────────

    environment.etc."nvidia-sdk/version".text = ''
      cuda: ${cudaPackage.version or "unknown"}
      driver: ${nvidiaDriver.version or "unknown"}
      open: ${lib.boolToString cfg.open}
      fhs: ${if cfg.fhs.enable then cfg.fhs.path else "disabled"}
    '';

    # ──────────────────────────────────────────────────────────────────────────
    # Assertions
    # ──────────────────────────────────────────────────────────────────────────

    assertions = [
      {
        assertion = cudaPackage != null;
        message = ''
          nvidia-sdk: CUDA package not found.
          Ensure overlay is applied: nixpkgs.overlays = [ inputs.nvidia-sdk.overlays.default ];
        '';
      }
    ];
  };
}
