# monitoring-tools.nix — GPU monitoring tools with NVML support
#
# Provides:
# - nvtop: GPU process monitor (htop for GPUs)
# - btop: System monitor with NVIDIA GPU support via NVML

{ lib, stdenv, fetchFromGitHub, cmake, ncurses, nvidia-sdk ? null, cuda ? nvidia-sdk }:

let
  # nvtop from nixpkgs with CUDA support
  nvtop = stdenv.mkDerivation rec {
    pname = "nvtop";
    version = "3.2.0";

    src = fetchFromGitHub {
      owner = "Syllo";
      repo = "nvtop";
      rev = version;
      hash = "sha256-qQdMXgAF6LhKUCFfKW4VZz2cuTW8AgVRCQZfnSN7IFo=";
    };

    nativeBuildInputs = [ cmake ];
    buildInputs = [ ncurses ] ++ lib.optional (cuda != null) cuda;

    cmakeFlags = [
      "-DNVML_INCLUDE_DIRS=${cuda}/include"
      "-DNVML_LIBRARIES=${cuda}/lib64/stubs/libnvidia-ml.so"
      "-DCUDA_INCLUDE_DIRS=${cuda}/include"
    ] ++ lib.optional (cuda != null) "-DNVIDIA_SUPPORT=ON";

    meta = with lib; {
      description = "GPU & Accelerator process monitoring";
      homepage = "https://github.com/Syllo/nvtop";
      license = licenses.gpl3Plus;
      platforms = platforms.linux;
    };
  };

  # btop with NVML support
  btop = stdenv.mkDerivation rec {
    pname = "btop";
    version = "1.4.3";

    src = fetchFromGitHub {
      owner = "aristocratos";
      repo = "btop";
      rev = "v${version}";
      hash = "sha256-UOUVrT+Ih+/2Ni8dMUJp7BbXhWE3Eo5G1rZa/YBu4oU=";
    };

    nativeBuildInputs = [ cmake ];
    buildInputs = lib.optional (cuda != null) cuda;

    cmakeFlags = lib.optionals (cuda != null) [
      "-DBTOP_GPU=ON"
      "-DCMAKE_CUDA_COMPILER=${cuda}/bin/nvcc"
    ];

    makeFlags = [ "PREFIX=$(out)" ];

    meta = with lib; {
      description = "Resource monitor with NVIDIA GPU support";
      homepage = "https://github.com/aristocratos/btop";
      license = licenses.asl20;
      platforms = platforms.linux;
    };
  };

  # Combined package with wrapper scripts
  monitoring-tools = stdenv.mkDerivation {
    pname = "nvidia-monitoring-tools";
    version = "1.0.0";

    dontUnpack = true;

    installPhase = ''
      mkdir -p $out/bin

      # Link nvtop
      ln -s ${nvtop}/bin/nvtop $out/bin/nvtop

      # Link btop
      ln -s ${btop}/bin/btop $out/bin/btop

      # Quick monitor script
      cat > $out/bin/gpu-monitor <<'EOF'
#!/bin/sh
# Quick GPU monitoring - shows nvidia-smi watch by default
exec watch -n 1 nvidia-smi
EOF
      chmod +x $out/bin/gpu-monitor
    '';

    meta = with lib; {
      description = "GPU monitoring tools for NVIDIA";
      platforms = platforms.linux;
    };
  };

in
{
  inherit nvtop btop monitoring-tools;
}
