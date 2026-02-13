# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Weyl AI
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  unzip,
  versions,
  cuda,
}:

stdenv.mkDerivation {
  pname = "nccl";
  version = versions.nccl.version;

  src = fetchurl {
    url = versions.nccl.${stdenv.hostPlatform.system}.url;
    hash = versions.nccl.${stdenv.hostPlatform.system}.hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    cuda
  ];

  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;

  # NCCL is distributed as a PyPI wheel (.whl = .zip)
  # containing nvidia/nccl/lib/ and nvidia/nccl/include/
  unpackPhase = ''
    unzip $src
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{lib,include}

    # PyPI wheel layout: nvidia/nccl/lib/*.so*, nvidia/nccl/include/*.h
    if [ -d nvidia/nccl/lib ]; then
      cp -a nvidia/nccl/lib/* $out/lib/
    fi
    if [ -d nvidia/nccl/include ]; then
      cp -a nvidia/nccl/include/* $out/include/
    fi

    ln -sf lib $out/lib64

    # Create unversioned symlink for linker
    ln -sf libnccl.so.2 $out/lib/libnccl.so

    mkdir -p $out/lib/pkgconfig
    cat > $out/lib/pkgconfig/nccl.pc << EOF
    prefix=$out
    libdir=\''${prefix}/lib
    includedir=\''${prefix}/include

    Name: NCCL
    Description: NVIDIA Collective Communication Library
    Version: ${versions.nccl.version}
    Libs: -L\''${libdir} -lnccl
    Cflags: -I\''${includedir}
    EOF

    runHook postInstall
  '';

  passthru.version = versions.nccl.version;

  meta = {
    description = "NVIDIA NCCL ${versions.nccl.version}";
    homepage = "https://developer.nvidia.com/nccl";
    license = lib.licenses.bsd3;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
