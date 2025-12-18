#!/usr/bin/env bash
set -euo pipefail

# Mirror ARM/SBSA packages to R2 and update versions.nix with hashes
# Usage: ./mirror-arm-to-r2.sh

REMOTE="weyl-ml-assets"
BUCKET_PATH="nvidia-redistributables"
VERSIONS_FILE="nix/versions.nix"

echo "=== ARM/SBSA Package Mirror Script ==="
echo ""

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# CUDA versions (in order)
CUDA_VERSIONS=(
  "12.9.1:575.57.08"
  "13.0.0:580.65.06"
  "13.0.1:580.82.07"
  "13.0.2:580.95.05"
  "13.1.0:590.44.01"
)

echo "=== Mirroring CUDA ARM/SBSA ==="
for entry in "${CUDA_VERSIONS[@]}"; do
  version="${entry%%:*}"
  driver="${entry##*:}"
  filename="cuda_${version}_${driver}_linux_sbsa.run"
  nvidia_url="https://developer.download.nvidia.com/compute/cuda/${version}/local_installers/${filename}"
  r2_path="${BUCKET_PATH}/cuda/${filename}"

  echo ">>> CUDA ${version} ARM/SBSA"

  # Check if already in R2
  if [[ -n $(rclone lsf "${REMOTE}:${r2_path}" 2>/dev/null) ]]; then
    echo "    ✓ Already in R2"
    continue
  fi

  # Download
  echo "    Downloading..."
  download_path="${TMP_DIR}/${filename}"
  if ! wget -q --show-progress -O "$download_path" "$nvidia_url"; then
    echo "    ✗ Download failed, skipping"
    continue
  fi

  # Calculate hash
  echo "    Calculating hash..."
  hash=$(nix-hash --type sha256 --base32 "$download_path" | xargs nix hash to-sri --type sha256)
  echo "    Hash: $hash"

  # Upload
  echo "    Uploading to R2..."
  rclone copy "$download_path" "${REMOTE}:${BUCKET_PATH}/cuda/" --progress

  # Update versions.nix hash for this CUDA version
  echo "    Updating versions.nix..."
  # Update cuda-versions."VERSION".aarch64-linux.hash using lazy matching
  perl -i -0777 -pe 's/("'"${version}"'".*?aarch64-linux.*?hash\s*=\s*)""/\1"'"${hash}"'"/s' "$VERSIONS_FILE"

  # Also update top-level cuda.aarch64-linux.hash if this is version 13.0.2 (the default)
  if [ "$version" = "13.0.2" ]; then
    echo "    Updating top-level cuda hash..."
    perl -i -0777 -pe 's/(^  cuda\s*=\s*\{.*?aarch64-linux.*?hash\s*=\s*)""/\1"'"${hash}"'"/sm' "$VERSIONS_FILE"
  fi

  rm "$download_path"
  echo ""
done

echo ""
echo "=== Mirroring cuDNN ARM/SBSA ==="
# cuDNN (from versions.nix)
cudnn_version="9.17.0.29"
cudnn_filename="cudnn-linux-sbsa-${cudnn_version}_cuda13-archive.tar.xz"
cudnn_url="https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-sbsa/${cudnn_filename}"

echo ">>> cuDNN ${cudnn_version} ARM/SBSA"
if [[ -z $(rclone lsf "${REMOTE}:${BUCKET_PATH}/cudnn/${cudnn_filename}" 2>/dev/null) ]]; then
  download_path="${TMP_DIR}/${cudnn_filename}"
  echo "    Downloading..."
  if wget -q --show-progress -O "$download_path" "$cudnn_url"; then
    echo "    Calculating hash..."
    hash=$(nix-hash --type sha256 --base32 "$download_path" | xargs nix hash to-sri --type sha256)
    echo "    Hash: $hash"
    echo "    Uploading..."
    rclone copy "$download_path" "${REMOTE}:${BUCKET_PATH}/cudnn/" --progress
    echo "    Updating versions.nix..."
    perl -i -0777 -pe 's/(cudnn\s*=\s*\{.*?aarch64-linux.*?hash\s*=\s*)""/\1"'"${hash}"'"/s' "$VERSIONS_FILE"
    rm "$download_path"
  fi
else
  echo "    ✓ Already in R2"
fi

echo ""
echo "=== Mirroring NCCL ARM/SBSA ==="
nccl_version="2.28.9"
nccl_filename="nccl_${nccl_version}-1+cuda13.0_aarch64.txz"
nccl_url="https://developer.download.nvidia.com/compute/nccl/redist/nccl/linux-sbsa/${nccl_filename}"

echo ">>> NCCL ${nccl_version} ARM/SBSA"
if [[ -z $(rclone lsf "${REMOTE}:${BUCKET_PATH}/nccl/${nccl_filename}" 2>/dev/null) ]]; then
  download_path="${TMP_DIR}/${nccl_filename}"
  echo "    Downloading..."
  if wget -q --show-progress -O "$download_path" "$nccl_url"; then
    echo "    Calculating hash..."
    hash=$(nix-hash --type sha256 --base32 "$download_path" | xargs nix hash to-sri --type sha256)
    echo "    Hash: $hash"
    echo "    Uploading..."
    rclone copy "$download_path" "${REMOTE}:${BUCKET_PATH}/nccl/" --progress
    echo "    Updating versions.nix..."
    perl -i -0777 -pe 's/(nccl\s*=\s*\{.*?aarch64-linux.*?hash\s*=\s*)""/\1"'"${hash}"'"/s' "$VERSIONS_FILE"
    rm "$download_path"
  fi
else
  echo "    ✓ Already in R2"
fi

echo ""
echo "=== Mirroring TensorRT ARM/SBSA ==="
tensorrt_version="10.14.1.48"
tensorrt_filename="TensorRT-${tensorrt_version}.Linux.aarch64-gnu.cuda-13.0.tar.gz"
tensorrt_url="https://developer.download.nvidia.com/compute/machine-learning/tensorrt/10.14.1/tars/${tensorrt_filename}"

echo ">>> TensorRT ${tensorrt_version} ARM/SBSA"
if [[ -z $(rclone lsf "${REMOTE}:${BUCKET_PATH}/tensorrt/${tensorrt_filename}" 2>/dev/null) ]]; then
  download_path="${TMP_DIR}/${tensorrt_filename}"
  echo "    Downloading..."
  if wget -q --show-progress -O "$download_path" "$tensorrt_url"; then
    echo "    Calculating hash..."
    hash=$(nix-hash --type sha256 --base32 "$download_path" | xargs nix hash to-sri --type sha256)
    echo "    Hash: $hash"
    echo "    Uploading..."
    rclone copy "$download_path" "${REMOTE}:${BUCKET_PATH}/tensorrt/" --progress
    echo "    Updating versions.nix..."
    perl -i -0777 -pe 's/(tensorrt\s*=\s*\{.*?aarch64-linux.*?hash\s*=\s*)""/\1"'"${hash}"'"/s' "$VERSIONS_FILE"
    rm "$download_path"
  fi
else
  echo "    ✓ Already in R2"
fi

echo ""
echo "=== Mirroring cuTensor ARM/SBSA ==="
cutensor_version="2.4.1.4"
cutensor_filename="libcutensor-linux-sbsa-${cutensor_version}_cuda13-archive.tar.xz"
cutensor_url="https://developer.download.nvidia.com/compute/cutensor/redist/libcutensor/linux-sbsa/${cutensor_filename}"

echo ">>> cuTensor ${cutensor_version} ARM/SBSA"
if [[ -z $(rclone lsf "${REMOTE}:${BUCKET_PATH}/libcutensor/${cutensor_filename}" 2>/dev/null) ]]; then
  download_path="${TMP_DIR}/${cutensor_filename}"
  echo "    Downloading..."
  if wget -q --show-progress -O "$download_path" "$cutensor_url"; then
    echo "    Calculating hash..."
    hash=$(nix-hash --type sha256 --base32 "$download_path" | xargs nix hash to-sri --type sha256)
    echo "    Hash: $hash"
    echo "    Uploading..."
    rclone copy "$download_path" "${REMOTE}:${BUCKET_PATH}/libcutensor/" --progress
    echo "    Updating versions.nix..."
    perl -i -0777 -pe 's/(cutensor\s*=\s*\{.*?aarch64-linux.*?hash\s*=\s*)""/\1"'"${hash}"'"/s' "$VERSIONS_FILE"
    rm "$download_path"
  fi
else
  echo "    ✓ Already in R2"
fi

echo ""
echo "=== Mirror Complete ==="
echo ""
echo "All ARM/SBSA packages have been uploaded to R2."
echo "Next: Update versions.nix URLs to use R2 instead of NVIDIA."
