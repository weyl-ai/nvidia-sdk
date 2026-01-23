#!/usr/bin/env bash
set -euo pipefail

# Mirror CUDA installers to R2 bucket (x86_64 and ARM/SBSA)
# Usage: ./mirror-cuda-to-r2.sh

REMOTE="weyl-ml-assets"
BUCKET_PATH="nvidia-redistributables"
BUCKET_URL="https://nvidia-redistributable.weyl.ai"

echo "=== Mirroring CUDA installers to R2 ==="
echo ""

# Array of CUDA versions to mirror
declare -A CUDA_VERSIONS=(
  ["12.9.1"]="575.57.08"
  ["13.0.0"]="580.65.06"
  ["13.0.1"]="580.82.07"
  ["13.0.2"]="580.95.05"
  ["13.1.0"]="590.44.01"
)

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

for version in "${!CUDA_VERSIONS[@]}"; do
  driver="${CUDA_VERSIONS[$version]}"

  # Mirror both x86_64 and ARM/SBSA
  for arch in "linux" "linux_sbsa"; do
    if [ "$arch" = "linux" ]; then
      arch_name="x86_64"
    else
      arch_name="aarch64 (SBSA)"
    fi

    filename="cuda_${version}_${driver}_${arch}.run"
    nvidia_url="https://developer.download.nvidia.com/compute/cuda/${version}/local_installers/${filename}"
    r2_path="${BUCKET_PATH}/cuda/${filename}"

    echo ">>> CUDA ${version} [${arch_name}]"
    echo "    Source: ${nvidia_url}"
    echo "    Dest:   ${BUCKET_URL}/${filename}"

    # Check if already exists in R2
    if rclone lsf "${REMOTE}:${r2_path}" &>/dev/null; then
      echo "    ✓ Already exists in R2, skipping"
      echo ""
      continue
    fi

    # Download from NVIDIA
    echo "    Downloading from NVIDIA..."
    download_path="${TMP_DIR}/${filename}"

    if ! wget -q --show-progress -O "$download_path" "$nvidia_url"; then
      echo "    ✗ Failed to download, skipping"
      echo ""
      continue
    fi

    # Get file size
    size=$(du -h "$download_path" | cut -f1)
    echo "    Downloaded: ${size}"

    # Upload to R2
    echo "    Uploading to R2..."
    if rclone copy "$download_path" "${REMOTE}:${BUCKET_PATH}/cuda/" --progress; then
      echo "    ✓ Uploaded successfully"
      rm "$download_path"
    else
      echo "    ✗ Upload failed"
    fi

    echo ""
  done
done

echo ""
echo "=== Mirroring TensorRT ==="
echo ""

# TensorRT versions (per CUDA version)
declare -A TENSORRT_VERSIONS=(
  ["10.14.1.48"]="13.0"
)

for trt_version in "${!TENSORRT_VERSIONS[@]}"; do
  cuda_ver="${TENSORRT_VERSIONS[$trt_version]}"

  for arch in "x86_64" "aarch64"; do
    if [ "$arch" = "x86_64" ]; then
      arch_name="x86_64"
    else
      arch_name="aarch64 (SBSA)"
    fi

    filename="TensorRT-${trt_version}.Linux.${arch}-gnu.cuda-${cuda_ver}.tar.gz"
    nvidia_url="https://developer.download.nvidia.com/compute/machine-learning/tensorrt/${trt_version%.*}/tars/${filename}"
    r2_path="${BUCKET_PATH}/tensorrt/${filename}"

    echo ">>> TensorRT ${trt_version} [${arch_name}]"
    echo "    Source: ${nvidia_url}"
    echo "    Dest:   ${BUCKET_URL}/tensorrt/${filename}"

    # Check if already exists in R2
    if rclone lsf "${REMOTE}:${r2_path}" &>/dev/null; then
      echo "    ⚠ Already exists in R2, skipping"
      echo ""
      continue
    fi

    # Download from NVIDIA
    echo "    Downloading from NVIDIA..."
    download_path="${TMP_DIR}/${filename}"

    if ! wget -q --show-progress -O "$download_path" "$nvidia_url"; then
      echo "    ✗ Failed to download (may require NVIDIA auth), skipping"
      echo ""
      continue
    fi

    # Get file size
    size=$(du -h "$download_path" | cut -f1)
    echo "    Downloaded: ${size}"

    # Upload to R2
    echo "    Uploading to R2..."
    if rclone copy "$download_path" "${REMOTE}:${BUCKET_PATH}/tensorrt/" --progress; then
      echo "    ✓ Uploaded successfully"
      rm "$download_path"
    else
      echo "    ✗ Upload failed"
    fi

    echo ""
  done
done

echo "=== Mirror complete ==="
echo ""
echo "⚠ WARNING: Some NVIDIA packages may have redistribution restrictions."
echo "   Consider encrypting non-redistributable packages or restricting access."
echo ""
echo "Next steps:"
echo "1. Review NVIDIA's redistribution licenses"
echo "2. Run: nix run .#update-cuda-urls"
echo "3. This will update versions.nix to use R2 URLs"
