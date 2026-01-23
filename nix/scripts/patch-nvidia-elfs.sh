#!/usr/bin/env bash
# Patches ELF files in NVIDIA SDK with proper library paths
# Usage: patch-nvidia-elfs.sh <output-dir> <qt-libs> <mesa-libs> <x11-libs> <sys-libs> <nsight-libs> <dynamic-linker>

set -euo pipefail

output_dir="$1"
qt_libs="$2"
mesa_libs="$3"
x11_libs="$4"
sys_libs="$5"
nsight_libs="$6"
dynamic_linker="$7"

extra_libs="$qt_libs:$mesa_libs:$x11_libs:$sys_libs:$nsight_libs"

echo "Patching ELF files with Qt6/Mesa/X11/Nsight libraries..."

# Patch ELF files in output directory
find "$output_dir" -type f \( -executable -o -name "*.so*" \) 2>/dev/null | while read -r f; do
  # Skip symlinks
  [ -L "$f" ] && continue

  # Skip non-ELF files
  file "$f" | grep -q ELF || continue

  # Set interpreter for executables
  if file "$f" | grep -q "executable"; then
    patchelf --set-interpreter "$dynamic_linker" "$f" 2>/dev/null || true
  fi

  # Update rpath
  existing=$(patchelf --print-rpath "$f" 2>/dev/null || echo "")
  new_rpath="$output_dir/lib:$output_dir/lib64:$extra_libs${existing:+:$existing}"
  patchelf --force-rpath --set-rpath "$new_rpath" "$f" 2>/dev/null || true
done

echo "ELF patching complete."
