# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Weyl AI
#
# nvidia-sdk version configuration
# NGC 25.12 — Canonical release for SM120 (Blackwell) and SM90 (Hopper)
#
# All binaries fetched directly from NVIDIA's official distribution channels:
#   - developer.download.nvidia.com (CUDA toolkit, cuDNN, TensorRT, cuTensor)
#   - files.pythonhosted.org (NCCL — BSD-3-Clause)
#   - github.com/NVIDIA (CUTLASS — BSD-3-Clause)

{
  # ════════════════════════════════════════════════════════════════════════════
  # NGC 25.12 — The Standard
  # ════════════════════════════════════════════════════════════════════════════

  ngc = {
    version = "25.12";
    cuda = "13.1";
    driver = "590.44.01";
    cudnn = "9.17.0.29";
    nccl = "2.28.9";
    tensorrt = "10.15.1.29";
    cutlass = "4.3.3";
  };

  # ════════════════════════════════════════════════════════════════════════════
  # CUDA 13.1 — Current
  # ════════════════════════════════════════════════════════════════════════════

  cuda = {
    version = "13.1";
    driver = "590.44.01";

    x86_64-linux = {
      url = "https://developer.download.nvidia.com/compute/cuda/13.1.0/local_installers/cuda_13.1.0_590.44.01_linux.run";
      hash = "sha256-a0/fJpSz16+8Um8mQStM9PBQsgIyRFUFMwcxD1OzI6c=";
    };

    aarch64-linux = {
      url = "https://developer.download.nvidia.com/compute/cuda/13.1.0/local_installers/cuda_13.1.0_590.44.01_linux_sbsa.run";
      hash = "sha256-Bs2kmnAxscmfeEI3vlyFJhk3nLupVVA2BFBEud3JkkA=";
    };
  };

  cudnn = {
    version = "9.17.0.29";
    x86_64-linux = {
      url = "https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-9.17.0.29_cuda13-archive.tar.xz";
      hash = "sha256-RV8VB1STyCoaiFCq5hIPP6b35FfL71bByy4KYYtbUJ4=";
    };

    aarch64-linux = {
      url = "https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-sbsa/cudnn-linux-sbsa-9.17.0.29_cuda13-archive.tar.xz";
      hash = "sha256-Gb5tjytjpFnmdYGFwej+7d7NtLVnF9xOS7z+MKBhm30=";
    };
  };

  nccl = {
    version = "2.28.9";

    # NCCL is BSD-3-Clause — fetched from PyPI (NVIDIA's official distribution)
    x86_64-linux = {
      url = "https://files.pythonhosted.org/packages/4a/4e/44dbb46b3d1b0ec61afda8e84837870f2f9ace33c564317d59b70bc19d3e/nvidia_nccl_cu12-2.28.9-py3-none-manylinux_2_18_x86_64.whl";
      hash = "sha256-SFd22qhEfaXaOWga9FWqOywlht3PSvh3JJXnxTLH5as=";
    };

    aarch64-linux = {
      url = "https://files.pythonhosted.org/packages/08/c4/120d2dfd92dff2c776d68f361ff8705fdea2ca64e20b612fab0fd3f581ac/nvidia_nccl_cu12-2.28.9-py3-none-manylinux_2_18_aarch64.whl";
      hash = "sha256-ubC3CGU4LFA7bLIz3RPkKJSh1dDA9oMSSgkFkpeQxzs=";
    };
  };

  tensorrt = {
    version = "10.15.1.29";

    x86_64-linux = {
      url = "https://developer.download.nvidia.com/compute/machine-learning/tensorrt/10.15.1/tars/TensorRT-10.15.1.29.Linux.x86_64-gnu.cuda-13.1.tar.gz";
      hash = "sha256-Li1ugAIh6EDh/H66el5LEzkM8UhWtLIa9ClpTiFgIiI=";
    };

    aarch64-linux = {
      url = "https://developer.download.nvidia.com/compute/machine-learning/tensorrt/10.15.1/tars/TensorRT-10.15.1.29.Linux.aarch64-gnu.cuda-13.1.tar.gz";
      hash = "sha256-3wwRKk1mvY74kGlyl+AVWNczjVxKyF1AeOgU5Qa9baI=";
    };
  };

  cutensor = {
    version = "2.4.1.4";

    x86_64-linux = {
      url = "https://developer.download.nvidia.com/compute/cutensor/redist/libcutensor/linux-x86_64/libcutensor-linux-x86_64-2.4.1.4_cuda13-archive.tar.xz";
      hash = "sha256-IfsKmjt7ZmMiNme1h/KrHFTkphyXX+oPnU9W2cM/Mf4=";
    };

    aarch64-linux = {
      url = "https://developer.download.nvidia.com/compute/cutensor/redist/libcutensor/linux-sbsa/libcutensor-linux-sbsa-2.4.1.4_cuda13-archive.tar.xz";
      hash = "sha256-m6/9Nli39NotL5TSPDrN220SximX09o5p3SgWP7wSqU=";
    };
  };

  cutlass = {
    version = "4.3.3";
    url = "https://github.com/NVIDIA/cutlass/archive/refs/tags/v4.3.3.zip";
    hash = "sha256-uOfSEjbwn/edHEgBikC9wAarn6c6T71ebPg74rv2qlw=";
  };

  # ════════════════════════════════════════════════════════════════════════════
  # SM Architecture Targets (Compute Capabilities)
  # ════════════════════════════════════════════════════════════════════════════
  # Source: https://developer.nvidia.com/cuda-gpus
  #         https://en.wikipedia.org/wiki/CUDA

  sm = {
    # Consumer / Workstation (x86_64)
    turing = "sm_75"; # RTX 20xx, GTX 16xx, Quadro RTX
    ampere = "sm_86"; # RTX 30xx, A-series workstation
    ada = "sm_89"; # RTX 40xx, L4, L40, RTX 6000 Ada
    blackwell-rtx = "sm_120"; # RTX 50xx (x86_64 only)

    # Data Center
    volta = "sm_70"; # V100
    ampere-dc = "sm_80"; # A100, A30
    hopper = "sm_90"; # H100, H200, GH200
    blackwell-dc = "sm_100"; # B100, B200, GB200 (SBSA aarch64)
    blackwell-gb = "sm_121"; # GB12 (SBSA aarch64)

    # Jetson / Tegra
    xavier = "sm_72"; # Jetson AGX Xavier
    orin = "sm_87"; # Jetson Orin
  };

  # ════════════════════════════════════════════════════════════════════════════
  # Driver Versions (for NixOS module)
  # ════════════════════════════════════════════════════════════════════════════
  # Drivers are installed by the NixOS module from nixpkgs.
  # These version references are for documentation only.

  driver = {
    version = "590.44.01";
    minimum = "590.44.01";
  };
}
