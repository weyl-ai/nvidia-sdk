# nvidia-sdk version configuration
# NGC 25.12 — Canonical release for SM120 (Blackwell) and SM90 (Hopper)
# Update via: `nix run .#update`

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
    triton = "25.12";
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
      urls = {
        mirror = "https://nvidia-redistributable.weyl.ai/cudnn/cudnn-linux-x86_64-9.17.0.29_cuda13-archive.tar.xz";
        upstream = "https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-9.17.0.29_cuda13-archive.tar.xz";
      };
      hash = "sha256-RV8VB1STyCoaiFCq5hIPP6b35FfL71bByy4KYYtbUJ4=";
    };

    aarch64-linux = {
      urls = {
        mirror = "https://nvidia-redistributable.weyl.ai/cudnn/cudnn-linux-sbsa-9.17.0.29_cuda13-archive.tar.xz";
        upstream = "https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-sbsa/cudnn-linux-sbsa-9.17.0.29_cuda13-archive.tar.xz";
      };
      hash = "sha256-Gb5tjytjpFnmdYGFwej+7d7NtLVnF9xOS7z+MKBhm30=";
    };
  };

  nccl = {
    version = "2.28.9";

    x86_64-linux = {
      urls = {
        mirror = "https://nvidia-redistributable.weyl.ai/nccl/nccl_2.28.9-1+cuda12.0_x86_64.txz";
        upstream = "https://files.pythonhosted.org/packages/4a/4e/44dbb46b3d1b0ec61afda8e84837870f2f9ace33c564317d59b70bc19d3e/nvidia_nccl_cu12-2.28.9-py3-none-manylinux_2_18_x86_64.whl";
      };
      hash = "sha256-Ta9tHpdQVel+xb22iGc+A2OwYSnAiT2UtdVNLs1zDTw=";
    };

    aarch64-linux = {
      urls = {
        mirror = "https://nvidia-redistributable.weyl.ai/nccl/nccl_2.28.9-1+cuda12.0_aarch64.txz";
        upstream = "https://files.pythonhosted.org/packages/08/c4/120d2dfd92dff2c776d68f361ff8705fdea2ca64e20b612fab0fd3f581ac/nvidia_nccl_cu12-2.28.9-py3-none-manylinux_2_18_aarch64.whl";
      };
      hash = "sha256-ubC3CGU4LFA7bLIz3RPkKJSh1dDA9oMSSgkFkpeQxzs=";
    };
  };

  tensorrt = {
    version = "10.15.1.29";

    x86_64-linux = {
      urls = {
        mirror = "https://nvidia-redistributable.weyl.ai/TensorRT-10.15.1.29.Linux.x86_64-gnu.cuda-13.1.tar.gz";
        upstream = "https://developer.download.nvidia.com/compute/machine-learning/tensorrt/10.15.1/tars/TensorRT-10.15.1.29.Linux.x86_64-gnu.cuda-13.1.tar.gz";
      };

      hash = "sha256-Li1ugAIh6EDh/H66el5LEzkM8UhWtLIa9ClpTiFgIiI=";
    };

    aarch64-linux = {
      urls = {
        mirror = "https://nvidia-redistributable.weyl.ai/TensorRT-10.15.1.29.Linux.aarch64-gnu.cuda-13.1.tar.gz";
        upstream = "https://developer.download.nvidia.com/compute/machine-learning/tensorrt/10.15.1/tars/TensorRT-10.15.1.29.Linux.aarch64-gnu.cuda-13.1.tar.gz";
      };

      hash = "sha256-3wwRKk1mvY74kGlyl+AVWNczjVxKyF1AeOgU5Qa9baI=";
    };
  };




  tensorrt-rtx = {
    version = "1.2.0.54";

    # TensorRT-RTX is x86-64 only (no ARM/SBSA support)
    x86_64-linux = {
      urls = {
        mirror = "https://nvidia-redistributable.weyl.ai/tensorrt-rtx/TensorRT-RTX-1.2.0.54-Linux-x86_64-cuda-13.0-Release-external.tar.gz";
        upstream = "https://developer.nvidia.com/downloads/tensorrt-rtx-1-2-0-54-linux-x86-64-cuda-13-0-release-external";
      };

      hash = "sha256-qLuPcRaMSJGmGK29e5+AM/06ZOo7DovybBn0chNuDPU=";
    };
  };

  cutensor = {
    version = "2.4.1.4";

    x86_64-linux = {
      urls = {
        mirror = "https://nvidia-redistributable.weyl.ai/libcutensor/libcutensor-linux-x86_64-2.4.1.4_cuda13-archive.tar.xz";
        upstream = "https://developer.download.nvidia.com/compute/cutensor/redist/libcutensor/linux-x86_64/libcutensor-linux-x86_64-2.4.1.4_cuda13-archive.tar.xz";
      };
      hash = "sha256-IfsKmjt7ZmMiNme1h/KrHFTkphyXX+oPnU9W2cM/Mf4=";
    };

    aarch64-linux = {
      urls = {
        mirror = "https://nvidia-redistributable.weyl.ai/libcutensor/libcutensor-linux-sbsa-2.4.1.4_cuda13-archive.tar.xz";
        upstream = "https://developer.download.nvidia.com/compute/cutensor/redist/libcutensor/linux-sbsa/libcutensor-linux-sbsa-2.4.1.4_cuda13-archive.tar.xz";
      };
      hash = "sha256-m6/9Nli39NotL5TSPDrN220SximX09o5p3SgWP7wSqU=";
    };
  };

  cutlass = {
    version = "4.3.3";
    url = "https://github.com/NVIDIA/cutlass/archive/refs/tags/v4.3.3.zip";
    hash = "sha256-uOfSEjbwn/edHEgBikC9wAarn6c6T71ebPg74rv2qlw=";
  };

  # ════════════════════════════════════════════════════════════════════════════
  # NGC Container — Triton + TensorRT-LLM (The Standard)
  # ════════════════════════════════════════════════════════════════════════════
  # Multi-arch container (amd64 + arm64)
  #
  # To update hashes:
  #   nix build .#python 2>&1 | grep "got:"
  # Or:
  #   crane export nvcr.io/nvidia/tritonserver:25.12-trtllm-python-py3 - | nix hash file --sri /dev/stdin

  triton-trtllm-container = {
    version = "25.12";

    # Same image ref for both - crane will pull the correct arch
    x86_64-linux = {
      ref = "nvcr.io/nvidia/tritonserver:25.12-trtllm-python-py3";
      hash = "sha256-WvHGKXzu1oJk8RRorIDaF9Ii6AuK6eAD7SIWRxs0vkk=";
    };

    aarch64-linux = {
      ref = "nvcr.io/nvidia/tritonserver:25.12-trtllm-python-py3";
      hash = "sha256-9hMiF7lZKLI64EMPQsb924VDG6L3wsTESmEVd85zAAU=";
    };
  };

  # ════════════════════════════════════════════════════════════════════════════
  # Nsight Profiling Tools (bundled with CUDA)
  # ════════════════════════════════════════════════════════════════════════════

  nsight = {
    compute = {
      version = "2025.4.0";
      x86_64-linux.path = "host/linux-desktop-glibc_2_11_3-x64";
      aarch64-linux.path = "host/linux-desktop-t210-a64";
    };

    systems = {
      version = "2025.5.2";
      x86_64-linux.path = "host-linux-x64";
      aarch64-linux.path = "host-linux-armv8";
    };
  };

  # ════════════════════════════════════════════════════════════════════════════
  # SM Architecture Targets (Compute Capabilities)
  # ════════════════════════════════════════════════════════════════════════════
  # Source: https://developer.nvidia.com/cuda-gpus
  #         https://en.wikipedia.org/wiki/CUDA

  sm = {
    # Consumer / Workstation (x86_64)
    turing = "sm_75";          # RTX 20xx, GTX 16xx, Quadro RTX
    ampere = "sm_86";          # RTX 30xx, A-series workstation
    ada = "sm_89";             # RTX 40xx, L4, L40, RTX 6000 Ada
    blackwell-rtx = "sm_120";  # RTX 50xx (x86_64 only)

    # Data Center
    volta = "sm_70";           # V100
    ampere-dc = "sm_80";      # A100, A30
    hopper = "sm_90";         # H100, H200, GH200
    blackwell-dc = "sm_100";  # B100, B200, GB200 (SBSA aarch64)
    blackwell-gb = "sm_121";  # GB12 (SBSA aarch64)

    # Jetson / Tegra
    xavier = "sm_72";         # Jetson AGX Xavier
    orin = "sm_87";           # Jetson Orin
  };

  # ════════════════════════════════════════════════════════════════════════════
  # Driver Versions (for NixOS module)
  # ════════════════════════════════════════════════════════════════════════════

  driver = {
    version = "590.44.01";

    x86_64-linux = {
      url = "https://us.download.nvidia.com/XFree86/Linux-x86_64/590.44.01/NVIDIA-Linux-x86_64-590.44.01.run";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";  # TODO: fetch
    };

    aarch64-linux = {
      url = "https://us.download.nvidia.com/XFree86/Linux-aarch64/590.44.01/NVIDIA-Linux-aarch64-590.44.01.run";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";  # TODO: fetch
    };

    # Open kernel module hashes (Turing+)
    open = {
      x86_64-linux.hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      aarch64-linux.hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
  };
}
