# Third-Party Licenses

This document contains license information for all NVIDIA SDK components included in this project.

## Summary

| Component | License | Source | Redistributable |
|-----------|---------|--------|-----------------|
| CUDA Toolkit | NVIDIA EULA | developer.download.nvidia.com | Runtime libs only |
| cuDNN | NVIDIA SLA | developer.download.nvidia.com | As part of apps |
| TensorRT | NVIDIA SLA | developer.download.nvidia.com | Runtime only |
| NCCL | BSD-3-Clause | PyPI | Yes |
| CUTLASS | BSD-3-Clause | GitHub | Yes |
| cuTensor | NVIDIA SLA | developer.download.nvidia.com | As part of apps |

---

## CUDA Toolkit

**Component:** NVIDIA CUDA Toolkit  
**Version:** 13.1  
**License Type:** NVIDIA CUDA Toolkit End User License Agreement (EULA)  
**Official License:** https://docs.nvidia.com/cuda/eula/  
**Source:** https://developer.download.nvidia.com/compute/cuda/

### Key Terms

- CUDA runtime libraries may be redistributed with applications that use them
- The CUDA compiler (nvcc) and development tools are NOT redistributable
- Use is limited to systems with NVIDIA GPUs
- No reverse engineering permitted

---

## cuDNN

**Component:** NVIDIA CUDA Deep Neural Network library (cuDNN)  
**Version:** 9.17.0.29  
**License Type:** NVIDIA cuDNN Software License Agreement (SLA)  
**Official License:** https://docs.nvidia.com/deeplearning/cudnn/latest/reference/eula.html  
**Source:** https://developer.download.nvidia.com/compute/cudnn/redist/

### Key Terms

- cuDNN libraries may be redistributed as part of applications
- Cannot be redistributed standalone or as a development kit
- Use restricted to NVIDIA GPU-based systems

---

## TensorRT

**Component:** NVIDIA TensorRT  
**Version:** 10.15.1.29  
**License Type:** NVIDIA TensorRT Software License Agreement (SLA)  
**Official License:** https://docs.nvidia.com/deeplearning/tensorrt/sla/index.html  
**Source:** https://developer.download.nvidia.com/compute/machine-learning/tensorrt/

### Key Terms

- TensorRT runtime libraries may be redistributed with applications
- Development headers and tools are NOT redistributable
- Must include NVIDIA attribution notice
- Use restricted to NVIDIA GPU-based systems

---

## NCCL

**Component:** NVIDIA Collective Communication Library (NCCL)  
**Version:** 2.28.9  
**License Type:** BSD-3-Clause  
**Source:** https://files.pythonhosted.org/packages/ (PyPI wheel)  
**GitHub:** https://github.com/NVIDIA/nccl

### License Text

```
Copyright (c) 2015-2025, NVIDIA CORPORATION. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
 * Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
 * Neither the name of NVIDIA CORPORATION, LAWRENCE BERKELEY NATIONAL
   LABORATORY, nor the names of their contributors may be used to endorse
   or promote products derived from this software without specific prior
   written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED.
```

---

## CUTLASS

**Component:** CUDA Templates for Linear Algebra Subroutines  
**Version:** 4.3.3  
**License Type:** BSD-3-Clause  
**Source:** https://github.com/NVIDIA/cutlass

### License Text

```
Copyright (c) 2017-2025, NVIDIA CORPORATION. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the NVIDIA CORPORATION nor the names of its
      contributors may be used to endorse or promote products derived from
      this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES ARE DISCLAIMED.
```

---

## cuTensor

**Component:** NVIDIA cuTENSOR  
**Version:** 2.4.1.4  
**License Type:** NVIDIA cuTENSOR Software License Agreement  
**Official License:** https://docs.nvidia.com/cuda/cutensor/latest/license.html  
**Source:** https://developer.download.nvidia.com/compute/cutensor/redist/

### Key Terms

- cuTensor may be redistributed as part of applications
- No standalone redistribution permitted
- Use restricted to NVIDIA GPU-based systems

---

## Nix Expressions

The Nix expressions in this repository are licensed under the MIT License:

```
MIT License

Copyright (c) 2025 Weyl AI

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

---

## Acceptance

By using this SDK, you agree to comply with all applicable license terms.
For NVIDIA proprietary components, see the [NVIDIA End User License Agreement](https://www.nvidia.com/en-us/drivers/nvidia-license/).
