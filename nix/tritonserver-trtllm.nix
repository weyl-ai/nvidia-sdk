{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  modern,
  file,
  patchelf,
  makeWrapper,
  unzip,
  python312,
  abseil-cpp,
  acl,
  audit,
  boost,
  bzip2,
  cuda,
  cudnn,
  curl,
  cutensor,
  cyrus_sasl,
  db,
  dbus,
  e2fsprogs,
  expat,
  gdbm,
  glib,
  gnutls,
  gperftools,
  grpc,
  icu,
  keyutils,
  libarchive,
  libbsd,
  libcap,
  libcap_ng,
  libevent,
  libffi,
  libgcrypt,
  libgpg-error,
  libkrb5,
  libmd,
  libselinux,
  libsemanage,
  libsepol,
  libssh,
  libuuid,
  libxcrypt,
  libxml2,
  lz4,
  nccl,
  ncurses,
  nettle,
  numactl,
  openldap,
  openmpi,
  openssl,
  pam,
  pcre,
  pcre2,
  protobuf,
  rapidjson,
  re2,
  readline,
  rtmpdump,
  systemd,
  tensorrt,
  triton-trtllm-container,
  tzdata,
  util-linux,
  versions,
  xz,
  zeromq,
  zlib,
}:

let
  python = python312;

  # tritonclient wheel for GRPC streaming support
  tritonclient-wheel = fetchurl {
    url = "https://files.pythonhosted.org/packages/py3/t/tritonclient/tritonclient-2.64.0-py3-none-manylinux1_x86_64.whl";
    hash = "sha256-TRZTZYulmzgLcylp5nhCssk1sUer0eiUWP1kqTNbH8c=";
  };

  # python-rapidjson (tritonclient dependency)
  rapidjson-wheel = fetchurl {
    url = "https://files.pythonhosted.org/packages/cp312/p/python_rapidjson/python_rapidjson-1.23-cp312-cp312-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
    hash = "sha256-YGeBDw/VdxPsczsLauJl7xaeE7LOBKSTixgHzd2LTbQ=";
  };

  # Use system libxml2 directly

  runtime-inputs = [
    cuda
    cudnn
    nccl
    tensorrt
    cutensor
    abseil-cpp
    boost
    curl
    gperftools
    grpc
    libevent
    libuuid
    numactl
    openmpi
    openssl
    protobuf
    rapidjson
    re2
    zlib
    stdenv.cc.cc.lib
    python
    libxml2
    libarchive
    icu
    lz4
    nettle
    acl
    cyrus_sasl
    gnutls
    libssh
    openldap
    rtmpdump
    expat
    ncurses
    bzip2
    xz
    libffi
    glib
    pcre2
    systemd
    libgcrypt
    libgpg-error
    libcap
    libcap_ng
    audit
    libselinux
    libsemanage
    libsepol
    pcre
    libkrb5
    keyutils
    dbus
    pam
    e2fsprogs.dev
    util-linux
    libmd
    libbsd
    readline
    gdbm
    db
    tzdata
    libxcrypt
    zeromq
  ];

  # include triton-trtllm-container so its /usr/lib* get onto RPATH as well
  runpath = modern.mk-runpath (runtime-inputs ++ [ triton-trtllm-container ]);

in
stdenv.mkDerivation {
  pname = "tritonserver-trtllm";
  version = versions.triton-trtllm-container.version;
  src = triton-trtllm-container;

  nativeBuildInputs = [
    autoPatchelfHook
    file
    patchelf
    makeWrapper
    unzip
  ];
  buildInputs = runtime-inputs;

  autoPatchelfIgnoreMissingDeps = [
    "libcuda.so.1"
    "libLLVM.so.18.1"
    "libgc.so.1"
    "libobjc_gc.so.4.0.0"
    "libonig.so.5"
    "libmpfr.so.6"
    "libxxhash.so.0"
    "libjq.so.1.0.4"
    "libcaffe2_nvrtc.so"
    "libsasl2.so.2"
    "libapt-pkg.so.6.0"
    "libapt-private.so.0.0"
    # TensorRT-LLM specific - provided at runtime by NVIDIA driver
    "libnvidia-ml.so.1"
  ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/{bin,lib,include,backends,python}

    copy_one() {
      local pattern="$1" extra="$2"
      local f
      f=$(find "$src" -name "$pattern" -type f 2>/dev/null | head -1 || true)
      [ -z "$f" ] && return 0
      echo "Copying $pattern from $f"
      cp -a "$f" $out/lib/
      base=$(basename "$f")
      eval "$extra"
    }

    # libcupti - get the CUDA 13 version from targets directory
    cupti=$(find $src/usr/local/cuda-*/targets/*/lib -name "libcupti.so.2025*" -type f 2>/dev/null | head -1 || true)
    if [ -n "$cupti" ]; then
      echo "Copying CUDA 13 libcupti from $cupti"
      cp -a "$cupti" $out/lib/
      base=$(basename "$cupti")
      ( cd $out/lib;
        ln -sf "$base" libcupti.so.13 || true
        ln -sf "$base" libcupti.so || true
      )
    fi

    # libb64
    find $src -name "libb64.so*" -type f 2>/dev/null -exec cp -a {} $out/lib/ \;

    # libdcgm* and libdcgmmoduleconfig*
    find $src -path "*/libdcgm*.so*" -type f 2>/dev/null | while read -r f; do
      echo "Copying DCGM lib from $f"
      cp -a "$f" $out/lib/
      base=$(basename "$f")
      case "$base" in
        libdcgm.so.*)
          ( cd $out/lib; ln -sf "$base" libdcgm.so.4 || true; ln -sf "$base" libdcgm.so || true )
          ;;
        libdcgmmoduleconfig.so.*)
          ( cd $out/lib; ln -sf "$base" libdcgmmoduleconfig.so.4 || true; ln -sf "$base" libdcgmmoduleconfig.so || true )
          ;;
      esac
    done

    # libcusparseLt
    find $src -name "libcusparseLt.so*" -type f 2>/dev/null | while read -r f; do
      echo "Copying libcusparseLt from $f"
      cp -a "$f" $out/lib/
      base=$(basename "$f")
      ( cd $out/lib; ln -sf "$base" libcusparseLt.so.0 || true; ln -sf "$base" libcusparseLt.so || true )
    done

    # libnvshmem*
    find $src -name "libnvshmem*.so*" -type f 2>/dev/null | while read -r f; do
      echo "Copying libnvshmem from $f"
      cp -a "$f" $out/lib/
      base=$(basename "$f")
      case "$base" in
        libnvshmem_host*.so*)
          ( cd $out/lib; ln -sf "$base" libnvshmem_host.so.3 || true; ln -sf "$base" libnvshmem_host.so || true )
          ;;
      esac
    done

    # libcaffe2_nvrtc
    find $src -name "libcaffe2_nvrtc.so*" -type f 2>/dev/null -exec cp -a {} $out/lib/ \;

    # ICU 74 from container
    find $src -name "libicu*.so.74*" -type f 2>/dev/null | while read -r f; do
      echo "Copying ICU lib from $f"
      cp -a "$f" $out/lib/
      base=$(basename "$f")
      libname=''${base%%.so.*}
      ( cd $out/lib;
        ln -sf "$base" "$libname.so.74" || true
        ln -sf "$base" "$libname.so" || true
      )
    done

    # tritonserver tree
    if [ -d $src/opt/tritonserver ]; then
      cp -a $src/opt/tritonserver/* $out/
      chmod -R u+w $out
    fi

    [ -d $out/lib ] && [ ! -e $out/lib64 ] && ln -s lib $out/lib64

    # tensorrt_llm
    if [ -d $src/opt/tensorrt_llm ]; then
      mkdir -p $out/tensorrt_llm
      cp -a $src/opt/tensorrt_llm/* $out/tensorrt_llm/
      chmod -R u+w $out/tensorrt_llm
    fi

    # Python bits
    for pydir in \
      $src/usr/lib/python3/dist-packages \
      $src/usr/local/lib/python3.12/dist-packages \
      $src/opt/tritonserver/python
    do
      [ -d "$pydir" ] && cp -a "$pydir"/* $out/python/ 2>/dev/null || true
    done

    # Install tritonclient for GRPC streaming
    unzip -o ${tritonclient-wheel} -d $TMPDIR/tc
    cp -a $TMPDIR/tc/tritonclient-*.data/purelib/* $out/python/

    # Install python-rapidjson (tritonclient dependency)
    unzip -o ${rapidjson-wheel} -d $TMPDIR/rj
    cp -a $TMPDIR/rj/rapidjson* $out/python/

    # NCCL from Nix
    if [ -d ${nccl}/lib ]; then
      for lib in ${nccl}/lib/libnccl*.so*; do
        [ -f "$lib" ] || continue
        ln -sf "$lib" $out/lib/$(basename "$lib") || true
        base=$(basename "$lib")
        case "$base" in
          libnccl.so.[0-9]*.[0-9]*)
            # Link versioned file to .so.2 and .so
            ( cd $out/lib; 
              ln -sf "$base" libnccl.so.2 || true
              ln -sf libnccl.so.2 libnccl.so || true
            )
            ;;
        esac
      done
    fi

    # generic .so → .so.* symlinks
    if [ -d $out/lib ]; then
      cd $out/lib
      for lib in *.so.*; do
        [ -f "$lib" ] || continue
        base=''${lib%%.so.*}
        [ -e "$base.so" ] || ln -sf "$lib" "$base.so" 2>/dev/null || true
      done
    fi

    chmod -R u+w $out || true

    # fix python shebangs
    find $out -type f \( -name "*.py" -o -perm -0100 \) | while read -r f; do
      [ -f "$f" ] || continue
      if head -1 "$f" 2>/dev/null | grep -q '^#!.*python'; then
        sed -i "1s|^#!.*python.*|#!${python}/bin/python|" "$f" 2>/dev/null || true
      fi
    done
  '';

  preFixup = ''
    addAutoPatchelfSearchPath $out/lib
    addAutoPatchelfSearchPath $out/tensorrt_llm/lib
    # Add container's bundled libraries (MKL, etc) to search path
    for dir in ${triton-trtllm-container}/usr/lib/x86_64-linux-gnu \
               ${triton-trtllm-container}/usr/local/lib \
               ${triton-trtllm-container}/opt/tritonserver/lib \
               ${triton-trtllm-container}/usr/lib; do
      [ -d "$dir" ] && addAutoPatchelfSearchPath "$dir"
    done
    ${modern.patch-elf {
      inherit runpath;
      out = "$out";
    }}
  '';

  postFixup = ''
    libPaths="$out/lib:$out/tensorrt_llm/lib:${runpath}"

    for exe in $out/bin/*; do
      [ -f "$exe" ] && [ -x "$exe" ] || continue
      wrapProgram "$exe" \
        --set TRITON_SERVER_ROOT "$out" \
        --prefix LD_LIBRARY_PATH : "$libPaths" \
        --prefix PYTHONPATH : "$out/python"
    done
  '';

  meta = {
    description = "NVIDIA Triton Inference Server with TensorRT-LLM Backend ${versions.triton-trtllm-container.version}";
    homepage = "https://developer.nvidia.com/nvidia-triton-inference-server";
    license = lib.licenses.bsd3;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "tritonserver";
  };
}
