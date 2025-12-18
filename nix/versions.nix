# nvidia-redist version configuration
# ngc 25.11 blessed for blackwell (sm_120)
# update via: nix run .#update

{
  cuda = {
    version = "13.0.2";
    driver = "580.95.05";
    x86_64-linux = {
      url = "https://developer.download.nvidia.com/compute/cuda/13.0.2/local_installers/cuda_13.0.2_580.95.05_linux.run";
      hash = "sha256-gaXQ0IcLogIu+wpTHcxgrb3Cu/97PvGdb9bYEFQGx3U=";
    };
    aarch64-linux = {
      url = "https://developer.download.nvidia.com/compute/cuda/13.0.2/local_installers/cuda_13.0.2_580.95.05_linux_sbsa.run";
      hash = "sha256-FIXME";
    };
  };

  cudnn = {
    version = "9.17.0.29";
    x86_64-linux = {
      url = "https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-9.17.0.29_cuda13-archive.tar.xz";
      hash = "sha256-RV8VB1STyCoaiFCq5hIPP6b35FfL71bByy4KYYtbUJ4=";
    };
    aarch64-linux = {
      url = "https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-sbsa/cudnn-linux-sbsa-9.16.0.29_cuda13-archive.tar.xz";
      hash = "sha256-x0r2fbV/Gg1+ZrsBq5Px7NpfrKxJHKduaA2DLx4DXOY=";
    };
  };

  nccl = {
    version = "2.28.9";
    x86_64-linux = {
      url = "https://developer.download.nvidia.com/compute/nccl/redist/nccl/linux-x86_64/nccl_2.28.9-1+cuda13.0_x86_64.txz";
      hash = "sha256-FIXME";
    };
    aarch64-linux = {
      url = "https://developer.download.nvidia.com/compute/nccl/redist/nccl/linux-sbsa/nccl_2.28.9-1+cuda13.0_aarch64.txz";
      hash = "sha256-FIXME";
    };
  };

  tensorrt = {
    version = "10.14.1.48";
    x86_64-linux = {
      url = "https://developer.download.nvidia.com/compute/machine-learning/tensorrt/10.14.1/tars/TensorRT-10.14.1.48.Linux.x86_64-gnu.cuda-13.0.tar.gz";
      hash = "sha256-FIXME";
    };
    aarch64-linux = {
      url = "https://developer.download.nvidia.com/compute/machine-learning/tensorrt/10.14.1/tars/TensorRT-10.14.1.48.Linux.aarch64-gnu.cuda-13.0.tar.gz";
      hash = "sha256-FIXME";
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
      hash = "sha256-m6/9NYe/TaK3PNJzyi35vWw0w7KnfNuQr12gufvwSqU=";
    };
  };

  cutlass = {
    version = "3.8.0";
    url = "https://github.com/NVIDIA/cutlass/archive/refs/tags/v3.8.0.tar.gz";
    hash = "sha256-FIXME";
  };

  triton-container = {
    version = "25.11";
    x86_64-linux = {
      ref = "nvcr.io/nvidia/tritonserver:25.11-py3";
      hash = "sha256-yrTbMURSSc5kx4KTegTErpDjCWcjb9Ehp7pOUtP34pM=";
    };
    aarch64-linux = {
      ref = "nvcr.io/nvidia/tritonserver:25.11-py3-igpu";
      hash = "sha256-FIXME";
    };
  };

  sm = {
    ada = "sm_89";
    hopper = "sm_100";
    blackwell = "sm_120";
  };
}
