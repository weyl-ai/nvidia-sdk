{
  lib,
  stdenv,
  writeShellScriptBin,
  nvidia-sdk,
}:

writeShellScriptBin "validate-nvidia-sdk" ''
  set -e

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  NVIDIA SDK Validation"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo

  # Check nvidia-sdk-validate exists and runs
  echo "┌─ Running nvidia-sdk-validate"
  ${nvidia-sdk}/bin/nvidia-sdk-validate
  echo

  # Check key binaries exist
  echo "┌─ Checking core CUDA binaries"
  for bin in nvcc ptxas fatbinary nvlink; do
    if [ -x "${nvidia-sdk}/bin/$bin" ]; then
      echo "  ✓ $bin"
    else
      echo "  ✗ $bin"
      exit 1
    fi
  done
  echo

  # Check Nsight tools
  echo "┌─ Checking Nsight profiling tools"
  for tool in ncu nsys ncu-ui nsys-ui; do
    if [ -x "${nvidia-sdk}/bin/$tool" ]; then
      # Tools exist and are executable - version check may fail without full install
      version_info=$(${nvidia-sdk}/bin/$tool --version 2>&1 | grep -v "^Error\|^ERROR" | head -1 || echo "executable present")
      if [ -z "$version_info" ]; then
        version_info="executable present"
      fi
      echo "  ✓ $tool ($version_info)"
    else
      echo "  ✗ $tool"
      exit 1
    fi
  done
  echo "  └─ Note: Nsight tools require full data directories for runtime use"
  echo

  # Check key libraries exist
  echo "┌─ Checking core libraries"
  for lib in libcudart libcublas libcufft libcudnn libnccl libnvinfer libcutensor; do
    if ls ${nvidia-sdk}/lib64/$lib*.so* >/dev/null 2>&1; then
      echo "  ✓ $lib"
    else
      echo "  ✗ $lib"
      exit 1
    fi
  done
  echo

  # Check includes exist
  echo "┌─ Checking headers"
  for header in cuda.h cudnn.h nccl.h NvInfer.h cutensor.h; do
    if [ -f "${nvidia-sdk}/include/$header" ]; then
      echo "  ✓ $header"
    else
      echo "  ✗ $header"
      exit 1
    fi
  done
  echo

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✓ All SDK validation checks passed!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
''
