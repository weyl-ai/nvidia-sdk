{ lib, stdenv, autoPatchelfHook, file, patchelf, makeWrapper, python312
, abseil-cpp, boost, curl, gperftools, grpc, libevent, libuuid, numactl
, openmpi, openssl, protobuf, rapidjson, re2, zlib, libxml2, libarchive
, icu, lz4, nettle, acl, cyrus_sasl, gnutls, libssh, openldap, rtmpdump
, versions, cuda, cudnn, nccl, tensorrt, cutensor, triton-container }:

let
  python = python312;

  runtime-inputs = [
    cuda cudnn nccl tensorrt cutensor
    abseil-cpp boost curl gperftools grpc libevent libuuid numactl
    openmpi openssl protobuf rapidjson re2 stdenv.cc.cc.lib zlib
    python libxml2 libarchive icu lz4 nettle acl
    cyrus_sasl gnutls libssh openldap rtmpdump
  ];

in stdenv.mkDerivation {
  pname = "tritonserver";
  version = versions.triton-container.version;

  src = triton-container;

  nativeBuildInputs = [ autoPatchelfHook file patchelf makeWrapper ];
  buildInputs = runtime-inputs;

  dontAutoPatchelf = true;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/{bin,lib,include,backends,python}

    if [ -d $src/opt/tritonserver ]; then
      cp -a $src/opt/tritonserver/* $out/
      chmod -R u+w $out
    fi

    [ -d $out/lib ] && [ ! -e $out/lib64 ] && ln -s lib $out/lib64

    if [ -d $src/opt/tensorrt_llm ]; then
      mkdir -p $out/tensorrt_llm
      cp -a $src/opt/tensorrt_llm/* $out/tensorrt_llm/
      chmod -R u+w $out/tensorrt_llm
    fi

    for pydir in \
      $src/usr/lib/python3/dist-packages \
      $src/usr/local/lib/python3.12/dist-packages \
      $src/opt/tritonserver/python
    do
      [ -d "$pydir" ] && cp -a "$pydir"/* $out/python/ 2>/dev/null || true
    done
    chmod -R u+w $out/python 2>/dev/null || true

    for libdir in \
      $src/usr/lib/x86_64-linux-gnu \
      $src/usr/lib \
      $src/usr/local/lib \
      $src/opt/*/lib \
      $src/lib/x86_64-linux-gnu \
      $src/lib
    do
      if [ -d "$libdir" ]; then
        find "$libdir" -maxdepth 1 \( -name "*.so" -o -name "*.so.*" \) -type f 2>/dev/null | \
          while read f; do
            case "$(basename "$f")" in
              libc.so*|libm.so*|libpthread.so*|libdl.so*|ld-linux*.so*) continue ;;
              *) cp -an "$f" $out/lib/ 2>/dev/null || true ;;
            esac
          done
      fi
    done

    for pattern in "libcupti.so*" "libnvshmem*.so*" "libcaffe2_nvrtc.so*" "libdcgm.so*"; do
      find $src -name "$pattern" -type f 2>/dev/null | \
        while read f; do cp -an "$f" $out/lib/ 2>/dev/null || true; done
    done

    pushd $out/lib
    for lib in *.so.*; do
      if [ -f "$lib" ]; then
        base=$(echo "$lib" | sed 's/\.so\..*//')
        ln -sf "$lib" "$base.so" 2>/dev/null || true
      fi
    done
    popd

    find $out -type f -name "*.py" -o -type f -perm /u+x | while read -r f; do
      if [ -f "$f" ] && head -1 "$f" 2>/dev/null | grep -q '^#!.*python'; then
        sed -i "1s|^#!.*python.*|#!${python}/bin/python|" "$f" 2>/dev/null || true
      fi
    done
  '';

  fixupPhase = ''
    local libPaths="$out/lib:$out/tensorrt_llm/lib:${lib.makeLibraryPath runtime-inputs}"

    find $out -type f | while read -r f; do
      if file "$f" | grep -q "ELF"; then
        if file "$f" | grep -q "ELF.*executable"; then
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$f" 2>/dev/null || true
        fi
        patchelf --set-rpath "$libPaths" "$f" 2>/dev/null || true
        patchelf --shrink-rpath "$f" 2>/dev/null || true
      fi
    done

    autoPatchelf $out || true

    for exe in $out/bin/*; do
      if [ -f "$exe" ] && [ -x "$exe" ]; then
        wrapProgram "$exe" \
          --set TRITON_SERVER_ROOT "$out" \
          --prefix LD_LIBRARY_PATH : "$libPaths" \
          --prefix PYTHONPATH : "$out/python"
      fi
    done
  '';

  meta = {
    description = "NVIDIA Triton Inference Server ${versions.triton-container.version}";
    homepage = "https://developer.nvidia.com/nvidia-triton-inference-server";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "tritonserver";
  };
}
