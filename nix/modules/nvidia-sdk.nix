# nixos-module.nix — NVIDIA SDK Module
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# A NixOS module for deploying NVIDIA CUDA with exact driver control.
#
# Philosophy:
#   - Explicit driver version control (no guessing)
#   - Selective exposure via envfs (no global pollution)
#   - Driver-CUDA version matching (correctness)
#   - nvidia-sdk as the complete stack (composition)
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.nvidia-sdk;

  # ══════════════════════════════════════════════════════════════════════════
  # DRIVER CONFIGURATION
  # ══════════════════════════════════════════════════════════════════════════

  # Exact driver version with all hashes
  # Users provide these via module options
  nvidiaDriver =
    if cfg.driver.version != null then
      config.boot.kernelPackages.nvidiaPackages.mkDriver {
        inherit (cfg.driver) version;
        sha256_64bit = cfg.driver.sha256_64bit;
        sha256_aarch64 = cfg.driver.sha256_aarch64;
        openSha256 = cfg.driver.openSha256;
        settingsSha256 = cfg.driver.settingsSha256;
        persistencedSha256 = cfg.driver.persistencedSha256;
      }
    else
      # Fallback to stable if no explicit version
      config.boot.kernelPackages.nvidiaPackages.stable;

  # ══════════════════════════════════════════════════════════════════════════
  # CUDA PACKAGE SELECTION
  # ══════════════════════════════════════════════════════════════════════════

  cudaPackage =
    if cfg.cudaVersion != null then
      pkgs."cuda-${cfg.cudaVersion}" or (
        throw "CUDA ${cfg.cudaVersion} not available. Use: nix flake show to see available versions."
      )
    else
      pkgs.nvidia-sdk;  # default: latest

  # ══════════════════════════════════════════════════════════════════════════
  # WRAPPER FOR CUDA PROGRAMS
  # ══════════════════════════════════════════════════════════════════════════

  # Wrap a program with CUDA access (via environment variables)
  wrapWithCuda = program:
    pkgs.writeShellScriptBin (lib.getName program) ''
      export CUDA_PATH="${cudaPackage}"
      export CUDA_HOME="${cudaPackage}"
      export LD_LIBRARY_PATH="${cudaPackage}/lib64:${cudaPackage}/lib:/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      export PATH="${cudaPackage}/bin''${PATH:+:$PATH}"
      exec ${program}/bin/${lib.getName program} "$@"
    '';

in
{
  # ════════════════════════════════════════════════════════════════════════
  # OPTIONS
  # ════════════════════════════════════════════════════════════════════════

  options.hardware.nvidia-sdk = {
    enable = lib.mkEnableOption "NVIDIA SDK (CUDA + driver with exact version control)";

    # ────────────────────────────────────────────────────────────────────────
    # Driver Configuration
    # ────────────────────────────────────────────────────────────────────────

    driver = {
      version = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "580.95.05";
        description = ''
          Exact NVIDIA driver version.

          Example for driver 580.95.05:
          ```nix
          hardware.nvidia-sdk.driver = {
            version = "580.95.05";
            sha256_64bit = "sha256-hJ7w746EK5gGss3p8RwTA9VPGpp2lGfk5dlhsv4Rgqc=";
            sha256_aarch64 = "sha256-F2wmUEaRrpR1Vz0TQSwVK4Fv13f3J9NJLtBe4UP2f14=";
            openSha256 = "sha256-RFwDGQOi9jVngVONCOB5m/IYKZIeGEle7h0+0yGnBEI=";
            settingsSha256 = "sha256-F2wmUEaRrpR1Vz0TQSwVK4Fv13f3J9NJLtBe4UP2f14=";
            persistencedSha256 = "sha256-qKnpl4WceGyWUvVMI+55jRZbRvvgQw9dhlTSzHm7W1w=";
          };
          ```

          If null, uses nixpkgs' stable driver.
        '';
      };

      sha256_64bit = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SHA256 hash for x86_64 driver";
      };

      sha256_aarch64 = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SHA256 hash for aarch64 driver";
      };

      openSha256 = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SHA256 hash for open kernel module";
      };

      settingsSha256 = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SHA256 hash for nvidia-settings";
      };

      persistencedSha256 = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SHA256 hash for nvidia-persistenced";
      };
    };

    # ────────────────────────────────────────────────────────────────────────
    # CUDA Configuration
    # ────────────────────────────────────────────────────────────────────────

    cudaVersion = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "13.0.2";
      description = ''
        CUDA version to use. If null, uses latest nvidia-sdk.

        Available versions: nix flake show github:weyl-ai/libmodern-nvidia-sdk
      '';
    };

    # ────────────────────────────────────────────────────────────────────────
    # Exposure Policy
    # ────────────────────────────────────────────────────────────────────────

    expose = lib.mkOption {
      type = lib.types.enum [ "none" "system" "selective" ];
      default = "none";
      description = ''
        How to expose CUDA:
        - "none": No global exposure (use wrapWithCuda for specific programs)
        - "system": Add to systemPackages (traditional approach)
        - "selective": Use envfs for FHS-compatible selective exposure (future)

        Recommended: "none" for production (explicit dependencies)
      '';
    };

    wrapPrograms = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.python3 pkgs.julia ]";
      description = ''
        Programs to wrap with CUDA access.

        Each program will be wrapped to have CUDA_PATH, LD_LIBRARY_PATH set.
      '';
    };

    # ────────────────────────────────────────────────────────────────────────
    # Hardware Configuration
    # ────────────────────────────────────────────────────────────────────────

    opengl.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable OpenGL support (required for graphics)";
    };

    openKernelModule = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use open-source kernel module (Turing+)";
    };

    powerManagement.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable NVIDIA power management";
    };

    # ────────────────────────────────────────────────────────────────────────
    # Monitoring Tools
    # ────────────────────────────────────────────────────────────────────────

    monitoring.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install GPU monitoring tools:
        - nvtop: GPU process monitor (like htop for GPUs)
        - btop: System monitor with NVIDIA GPU support via NVML
        
        nvidia-smi is always available from the driver.
      '';
    };

    # ────────────────────────────────────────────────────────────────────────
    # Container Runtime
    # ────────────────────────────────────────────────────────────────────────

    container.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable NVIDIA Container Toolkit for Docker/Podman GPU access.
        
        Uses CDI (Container Device Interface) for modern container runtimes.
        Automatically configures Docker and Podman to access GPUs.
      '';
    };

    # ────────────────────────────────────────────────────────────────────────
    # Persistenced
    # ────────────────────────────────────────────────────────────────────────

    nvidiaPersistenced = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable nvidia-persistenced daemon for headless/server setups.
        
        Keeps GPU initialized even without X11/Wayland, essential for:
        - Headless compute workloads
        - Faster CUDA initialization
        - Container workloads
        - Reduced latency for first GPU access
      '';
    };
  };

  # ════════════════════════════════════════════════════════════════════════
  # IMPLEMENTATION
  # ════════════════════════════════════════════════════════════════════════

  config = lib.mkIf cfg.enable {
    # ──────────────────────────────────────────────────────────────────────
    # Driver Setup
    # ──────────────────────────────────────────────────────────────────────

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      package = nvidiaDriver;
      open = cfg.openKernelModule;
      nvidiaSettings = lib.mkDefault true;
      modesetting.enable = lib.mkDefault true;

      powerManagement = {
        enable = cfg.powerManagement.enable;
        finegrained = lib.mkDefault false;
      };
    };

    # ──────────────────────────────────────────────────────────────────────
    # OpenGL/Graphics
    # ──────────────────────────────────────────────────────────────────────

    hardware.graphics = lib.mkIf cfg.opengl.enable {
      enable = true;
      enable32Bit = lib.mkDefault true;
    };

    # ──────────────────────────────────────────────────────────────────────
    # CUDA Exposure
    # ──────────────────────────────────────────────────────────────────────

    # System packages
    environment.systemPackages = lib.mkMerge [
      # System-wide CUDA exposure
      (lib.mkIf (cfg.expose == "system") [ cudaPackage ])
      
      # Wrapped programs (explicit dependencies)
      (lib.mkIf (cfg.wrapPrograms != [ ]) (map wrapWithCuda cfg.wrapPrograms))
      
      # GPU monitoring tools - disabled, install separately via:
      # - nix-shell -p nvtop btop
      # - home-manager: home.packages = [ pkgs.nvtop pkgs.btop ];
      # - environment.systemPackages = [ pkgs.nvtop pkgs.btop ];
      # (lib.mkIf cfg.monitoring.enable [ pkgs.nvtop pkgs.btop ])
    ];

    # ──────────────────────────────────────────────────────────────────────
    # NVIDIA Persistenced (for headless/server use)
    # ──────────────────────────────────────────────────────────────────────

    systemd.services.nvidia-persistenced = lib.mkIf cfg.nvidiaPersistenced {
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

    # ──────────────────────────────────────────────────────────────────────
    # Container Runtime (Docker/Podman GPU Access)
    # ──────────────────────────────────────────────────────────────────────

    # Enable NVIDIA Container Toolkit
    hardware.nvidia-container-toolkit.enable = lib.mkIf cfg.container.enable true;

    # Configure Docker with CDI support
    virtualisation.docker = lib.mkIf cfg.container.enable {
      daemon.settings = {
        features.cdi = true;
      };
    };

    # Configure Podman with CDI support (if enabled)
    virtualisation.podman = lib.mkIf (cfg.container.enable && config.virtualisation.podman.enable) {
      extraPackages = [ pkgs.nvidia-container-toolkit ];
    };

    # Environment variables (only if system-wide)
    environment.variables = lib.mkIf (cfg.expose == "system") {
      CUDA_PATH = "${cudaPackage}";
      CUDA_HOME = "${cudaPackage}";
    };

    # ──────────────────────────────────────────────────────────────────────
    # Metadata
    # ──────────────────────────────────────────────────────────────────────

    environment.etc."nvidia-sdk-version".text = ''
      NVIDIA SDK: ${cudaPackage.version or "unknown"}
      Driver: ${nvidiaDriver.version or "unknown"}
      Exposure: ${cfg.expose}
      Source: github:weyl-ai/libmodern-nvidia-sdk
    '';

    # ──────────────────────────────────────────────────────────────────────
    # Assertions
    # ──────────────────────────────────────────────────────────────────────

    assertions = [
      {
        assertion = cfg.driver.version == null || (
          cfg.driver.sha256_64bit != "" &&
          cfg.driver.openSha256 != "" &&
          cfg.driver.settingsSha256 != "" &&
          cfg.driver.persistencedSha256 != ""
        );
        message = ''
          hardware.nvidia-sdk: When specifying driver.version, all hashes must be provided:
          - sha256_64bit
          - sha256_aarch64 (for aarch64)
          - openSha256
          - settingsSha256
          - persistencedSha256
        '';
      }
      {
        assertion = cudaPackage != null;
        message = ''
          hardware.nvidia-sdk: CUDA package not found.

          Ensure libmodern-nvidia-sdk overlay is applied:
            nixpkgs.overlays = [ inputs.libmodern-nvidia-sdk.overlays.default ];
        '';
      }
    ];

    # ──────────────────────────────────────────────────────────────────────
    # Warnings
    # ──────────────────────────────────────────────────────────────────────

    warnings = lib.optional (cfg.expose == "system") ''
      hardware.nvidia-sdk: expose = "system" adds CUDA globally.

      For better isolation, use expose = "none" and wrapPrograms instead:
        hardware.nvidia-sdk.wrapPrograms = [ pkgs.python3 ];
    '';
  };
}
