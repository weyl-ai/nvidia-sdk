# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Weyl AI
#
# nix/lib/licenses.nix — Custom NVIDIA License Definitions
#
# These components are proprietary. Redistribution is permitted only as part
# of applications per NVIDIA EULA terms. Standalone redistribution of these
# components is NOT permitted.

{ lib }:

{
  nvidiaCuda = {
    shortName = "CUDA";
    fullName = "NVIDIA CUDA Toolkit License";
    url = "https://docs.nvidia.com/cuda/eula/index.html";
    free = false;
    redistributable = false; # Runtime libs only; nvcc/tools are not redistributable
  };

  nvidiaCudnn = {
    shortName = "cuDNN";
    fullName = "NVIDIA cuDNN Software License Agreement";
    url = "https://docs.nvidia.com/deeplearning/cudnn/latest/reference/eula.html";
    free = false;
    redistributable = false; # Only redistributable as part of applications
  };

  nvidiaTensorrt = {
    shortName = "TensorRT";
    fullName = "NVIDIA TensorRT Software License Agreement";
    url = "https://docs.nvidia.com/deeplearning/tensorrt/sla/index.html";
    free = false;
    redistributable = false; # Runtime only; headers/tools are not redistributable
  };

  nvidiaCutensor = {
    shortName = "cuTENSOR";
    fullName = "NVIDIA cuTENSOR Software License Agreement";
    url = "https://docs.nvidia.com/cuda/cutensor/latest/license.html";
    free = false;
    redistributable = false; # Only redistributable as part of applications
  };
}
