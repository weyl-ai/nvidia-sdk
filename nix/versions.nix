# nvidia-redististributables version configuration
# ngc 25.11 blessed for `sm_120` and `sm_100`
# update via: `nix run .#update`

{
  # Default/active CUDA version
  # Note: CUDA versions specify minimum driver requirements.
  # Newer drivers (e.g. 580.119.02, 580.126.09) are backward compatible
  # and will work with older CUDA releases that require earlier drivers.
  cuda = {
    version = "13.0.2";
    driver = "580.95.05";  # minimum required driver
    x86_64-linux = {
      url = "https://developer.download.nvidia.com/compute/cuda/13.0.2/local_installers/cuda_13.0.2_580.95.05_linux.run";
      hash = "sha256-gaXQ0IcLogIu+wpTHcxgrb3Cu/97PvGdb9bYEFQGx3U=";
    };

    aarch64-linux = {
      url = "https://developer.download.nvidia.com/compute/cuda/13.0.2/local_installers/cuda_13.0.2_580.95.05_linux_sbsa.run";
      hash = "sha256-uXftBJGQu3qwhzuFoID5OcZ5w2iHFhxH1bmmlDnWMLc=";
    };
  };

  # All supported CUDA versions
  cuda-versions = {
    "12.9.1" = {
      version = "12.9.1";
      driver = "575.57.08";
      driver-windows = "576.57";
      x86_64-linux = {
        url = "https://developer.download.nvidia.com/compute/cuda/12.9.1/local_installers/cuda_12.9.1_575.57.08_linux.run";
        hash = "sha256-D22Abd2HIw0q2+imAGqdIBRP29qd4tasxnfapdA2QXo=";
      };
      aarch64-linux = {
        url = "https://developer.download.nvidia.com/compute/cuda/12.9.1/local_installers/cuda_12.9.1_575.57.08_linux_sbsa.run";
        hash = "sha256-uXftBJGQu3qwhzuFoID5OcZ5w2iHFhxH1bmmlDnWMLc=";
      };
    };

    "13.0.0" = {
      version = "13.0.0";
      driver = "580.65.06";
      x86_64-linux = {
        url = "https://developer.download.nvidia.com/compute/cuda/13.0.0/local_installers/cuda_13.0.0_580.65.06_linux.run";
        hash = "sha256-xklp81rZm/P56Ky449IjVRUMbKB6zBaoU3eGAKm2W6Y=";
      };
      aarch64-linux = {
        url = "https://developer.download.nvidia.com/compute/cuda/13.0.0/local_installers/cuda_13.0.0_580.65.06_linux_sbsa.run";
        hash = "sha256-mYFIjbt+W1eGQ6K407OWR1qiixnQlK7hnKzrAo++ysY=";
      };
    };

    "13.0.1" = {
      version = "13.0.1";
      driver = "580.82.07";
      x86_64-linux = {
        url = "https://developer.download.nvidia.com/compute/cuda/13.0.1/local_installers/cuda_13.0.1_580.82.07_linux.run";
        hash = "sha256-THrFnR9B1nvifRQKRiKAFzitcQiFcKD6z9bsh4pMQQA=";
      };
      aarch64-linux = {
        url = "https://developer.download.nvidia.com/compute/cuda/13.0.1/local_installers/cuda_13.0.1_580.82.07_linux_sbsa.run";
        hash = "sha256-mraFNGvleeP4xcKVjS4nfa6q7WEGU1i2jFL05jRLKK0=";
      };
    };

    "13.0.2" = {
      version = "13.0.2";
      driver = "580.95.05";
      x86_64-linux = {
        url = "https://developer.download.nvidia.com/compute/cuda/13.0.2/local_installers/cuda_13.0.2_580.95.05_linux.run";
        hash = "sha256-gaXQ0IcLogIu+wpTHcxgrb3Cu/97PvGdb9bYEFQGx3U=";
      };
      aarch64-linux = {
        url = "https://developer.download.nvidia.com/compute/cuda/13.0.2/local_installers/cuda_13.0.2_580.95.05_linux_sbsa.run";
        hash = "sha256-uXftBJGQu3qwhzuFoID5OcZ5w2iHFhxH1bmmlDnWMLc=";
      };
    };

    "13.1" = {
      version = "13.1";
      driver = "590.44.01";
      x86_64-linux = {
        url = "https://developer.download.nvidia.com/compute/cuda/13.1.0/local_installers/cuda_13.1.0_590.44.01_linux.run";
        hash = "sha256-a0/fJpSz16+8Um8mQStM9PBQsgIyRFUFMwcxD1OzI6c=";
      };
      aarch64-linux = {
        url = "https://developer.download.nvidia.com/compute/cuda/13.1.0/local_installers/cuda_13.1.0_590.44.01_linux_sbsa.run";
        hash = "sha256-+tMPYa/EYOkh/TGaIzxBQQSn/hPurmfUMfvTBEo5CbM=";
      };
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
      hash = "sha256-RV8VB1STyCoaiFCq5hIPP6b35FfL71bByy4KYYtbUJ4=";
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
    version = "10.14.1.48";

    x86_64-linux = {
      urls = {
        mirror = "https://nvidia-redistributable.weyl.ai/tensorrt/TensorRT-10.14.1.48.Linux.x86_64-gnu.cuda-12.9.tar.gz";
        upstream = "https://developer.download.nvidia.com/compute/machine-learning/tensorrt/10.14.1/tars/TensorRT-10.14.1.48.Linux.x86_64-gnu.cuda-13.0.tar.gz";
      };
      hash = "sha256-Dap9WSnHjt++hrR0Bk0PgtIGTEdcxr50fFEB8czDcQU=";
    };

    aarch64-linux = {
      urls = {
        mirror = "https://nvidia-redistributable.weyl.ai/tensorrt/TensorRT-10.14.1.48.Linux.aarch64-gnu.cuda-13.0.tar.gz";
        upstream = "https://developer.download.nvidia.com/compute/machine-learning/tensorrt/10.14.1/tars/TensorRT-10.14.1.48.Linux.aarch64-gnu.cuda-13.0.tar.gz";
      };
      hash = "sha256-qIhGr1FEQy++ziTOzgFUNFlf5MwTveSLFfeHydBoQps=";
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
      hash = "sha256-m6/9NYe/TaK3PNJzyi35vWw0w7KnfNuQr12gufvwSqU=";
    };
  };

  cutlass = {
    version = "4.3.3";
    url = "https://github.com/NVIDIA/cutlass/archive/refs/tags/v4.3.3.zip";
    hash = "sha256-uOfSEjbwn/edHEgBikC9wAarn6c6T71ebPg74rv2qlw=";
  };

  triton-container = {
    version = "25.12";

    x86_64-linux = {
      ref = "nvcr.io/nvidia/tritonserver:25.12-py3";
      hash = "sha256-HbL0FJ/c7UdLn8xIGBw5Vs5V+6cIo9vvZQPJH+x+R9E=";
    };

    aarch64-linux = {
      ref = "nvcr.io/nvidia/tritonserver:25.12-py3-igpu";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";  # TODO: update when needed
    };
  };

  # TensorRT-LLM Triton container (separate from standard triton)
  triton-trtllm-container = {
    version = "25.12";

    x86_64-linux = {
      ref = "nvcr.io/nvidia/tritonserver:25.12-trtllm-python-py3";
      hash = "sha256-WvHGKXzu1oJk8RRorIDaF9Ii6AuK6eAD7SIWRxs0vkk=";
    };

    aarch64-linux = {
      ref = "nvcr.io/nvidia/tritonserver:25.12-trtllm-python-py3";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";  # TODO: update when needed
    };
  };

  # Nsight profiling tools versions (bundled with CUDA)
  nsight = {
    compute = {
      version = "2025.3.1";
      x86_64-linux.path = "host/linux-desktop-glibc_2_11_3-x64";
      aarch64-linux.path = "host/linux-desktop-glibc_2_11_3-sbsa";
    };
    systems = {
      version = "2025.3.2";
      x86_64-linux.path = "host-linux-x64";
      aarch64-linux.path = "host-linux-sbsa";
    };
  };

  sm = {
    ada = "sm_89";
    hopper = "sm_100";
    blackwell = "sm_120";
  };

  # Nsight Deep Learning Designer (ONNX editor, TensorRT profiler)
  nsight-dl-designer = {
    version = "2025.5.25345";

    x86_64-linux = {
      url = "https://nvidia-redistributable.weyl.ai/NVIDIA_DeepLearning_2025.5.25345.0706_2025_12_11_0706_37034082_RelDL_DLD_A_Release_Public-Linux.linux.run";
      hash = "sha256-Oe04QctiHV86GPtCwqiuNB231hZtD87gpOR+uv6+zm8=";
    };

    aarch64-linux = {
      url = "https://nvidia-redistributable.weyl.ai/NVIDIA_DeepLearning_2025.5.25345.0706_2025_12_11_0706_37034082_RelDL_DLD_A_Release_Public-LinuxSBSA.sbsa.run";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";  # TODO: obtain ARM version from NVIDIA
    };
  };
}
