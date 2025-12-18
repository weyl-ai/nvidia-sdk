#!/usr/bin/env bash
# Simple test to verify the NixOS module is exported correctly

set -euo pipefail

echo "=== Testing NixOS Module ==="
echo

echo "1. Checking module is exported in flake..."
nix flake show 2>&1 | grep -q "nixosModules" && echo "✓ nixosModules found" || {
  echo "✗ nixosModules not found"
  exit 1
}

echo "2. Checking module file exists..."
[ -f nix/modules/nvidia-sdk.nix ] && echo "✓ Module file exists" || {
  echo "✗ Module file missing (expected nix/modules/nvidia-sdk.nix)"
  exit 1
}

echo "3. Checking module can be imported..."
nix eval --impure --expr 'builtins.isFunction (import ./nix/modules/nvidia-sdk.nix)' | grep -q "true" && echo "✓ Module is a function" || {
  echo "✗ Module is not a valid function"
  exit 1
}

echo "4. Checking example configuration..."
[ -f examples/nixos-configuration.nix ] && echo "✓ Example config exists" || {
  echo "✗ Example config missing"
  exit 1
}

echo "5. Checking documentation..."
[ -f docs/NIXOS-MODULE.md ] && echo "✓ Documentation exists" || {
  echo "✗ Documentation missing"
  exit 1
}

echo
echo "=== All module checks passed! ==="
echo
echo "Usage example:"
echo "  inputs.nvidia-sdk.nixosModules.default"
echo
echo "See docs/NIXOS-MODULE.md for complete documentation."
