final: prev:
let
  patchedClangUnwrapped = prev.llvmPackages_20.clang-unwrapped.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      echo "Applying sm_120 and sm_101 support patches..."

      # Patch include/clang/Basic/BuiltinsNVPTX.td - add SM_120 and SM_101 support
      # Only patch if not already present (idempotent)
      if ! grep -q "SM_120a" include/clang/Basic/BuiltinsNVPTX.td; then
        # Insert new SM definitions before SM_100
        sed -i '/^let Features = "sm_100a"/ i\
let Features = "sm_120a" in def SM_120a : SMFeatures;\
let Features = "sm_101a" in def SM_101a : SMFeatures;' include/clang/Basic/BuiltinsNVPTX.td

        # Insert new SM declarations before SM_100 definition
        sed -i '/^def SM_100 : SM<"100",/ i\
def SM_120 : SM<"120", [SM_120a]>;\
def SM_101 : SM<"101", [SM_101a, SM_120]>;' include/clang/Basic/BuiltinsNVPTX.td
      fi

      # Patch include/clang/Basic/Cuda.h - add enum values
      if ! grep -q "SM_120" include/clang/Basic/Cuda.h; then
        sed -i '/SM_100a,/a\  SM_101,\n  SM_101a,\n  SM_120,\n  SM_120a,' include/clang/Basic/Cuda.h
      fi

      # Patch lib/Basic/Cuda.cpp - add architecture names
      if ! grep -q 'SM(120)' lib/Basic/Cuda.cpp; then
        sed -i '/SM(100a),.*Blackwell/a\    SM(101),                         // Blackwell\n    SM(101a),                        // Blackwell\n    SM(120),                         // Blackwell\n    SM(120a),                        // Blackwell' lib/Basic/Cuda.cpp
      fi

      # Patch lib/Basic/Cuda.cpp - add version requirements
      if ! grep -q 'case OffloadArch::SM_120:' lib/Basic/Cuda.cpp; then
        sed -i '/case OffloadArch::SM_100a:/a\  case OffloadArch::SM_101:\n  case OffloadArch::SM_101a:\n  case OffloadArch::SM_120:\n  case OffloadArch::SM_120a:' lib/Basic/Cuda.cpp
      fi

      # Patch lib/Basic/Targets/NVPTX.cpp - add CUDA_ARCH values
      if ! grep -q 'case OffloadArch::SM_120:' lib/Basic/Targets/NVPTX.cpp; then
        sed -i '/case OffloadArch::SM_100a:/a\        return "1010";\n      case OffloadArch::SM_101:\n      case OffloadArch::SM_101a:\n        return "1010";\n      case OffloadArch::SM_120:\n      case OffloadArch::SM_120a:\n        return "1200";' lib/Basic/Targets/NVPTX.cpp
      fi

      echo "sm_120 support patches applied successfully"
    '';
  });
in
{
  llvmPackages_20 = prev.llvmPackages_20 // {
    clang-unwrapped = patchedClangUnwrapped;
    clang = prev.llvmPackages_20.clang.override {
      cc = patchedClangUnwrapped;
    };
  };
}
