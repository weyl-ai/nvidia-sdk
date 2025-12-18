{ lib, stdenv, fetchFromGitHub, cmake, versions }:

stdenv.mkDerivation {
  pname = "cutlass";
  version = versions.cutlass.version;

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cutlass";
    rev = "v${versions.cutlass.version}";
    hash = versions.cutlass.hash;
  };

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [
    "-DCUTLASS_ENABLE_HEADERS_ONLY=ON"
    "-DCUTLASS_ENABLE_TESTS=OFF"
    "-DCUTLASS_ENABLE_EXAMPLES=OFF"
  ];

  meta = {
    description = "NVIDIA CUTLASS ${versions.cutlass.version} - CUDA Templates for Linear Algebra";
    homepage = "https://github.com/NVIDIA/cutlass";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
