{ lib, stdenv, patchelf, file, versions, cuda, triton-container }:

stdenv.mkDerivation {
  pname = "nccl";
  version = versions.nccl.version;

  src = triton-container;

  nativeBuildInputs = [ patchelf file ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/{lib,include}

    find $src/usr/lib $src/usr/local/lib $src/opt -name "libnccl*.so*" -type f 2>/dev/null | \
      while read f; do cp -an "$f" $out/lib/ 2>/dev/null || true; done

    find $src/usr/include $src/usr/local/include $src/opt -name "nccl*.h" -type f 2>/dev/null | \
      while read f; do cp -an "$f" $out/include/ 2>/dev/null || true; done

    ln -sf lib $out/lib64

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
  '';

  fixupPhase = ''
    find $out -type f \( -executable -o -name "*.so*" \) 2>/dev/null | while read -r f; do
      [ -L "$f" ] && continue
      file "$f" | grep -q ELF || continue
      patchelf --set-rpath "${cuda}/lib:${cuda}/lib64:$out/lib" "$f" 2>/dev/null || true
    done
  '';

  passthru.version = versions.nccl.version;

  meta = {
    description = "NVIDIA NCCL ${versions.nccl.version}";
    homepage = "https://developer.nvidia.com/nccl";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
