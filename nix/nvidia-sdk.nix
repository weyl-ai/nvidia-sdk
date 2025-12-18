{ lib, stdenv, symlinkJoin, makeWrapper
, versions, cuda, cudnn, nccl, tensorrt, cutlass, cutensor }:

let
  merged = symlinkJoin {
    name = "nvidia-sdk-${versions.cuda.version}-merged";
    paths = [ cuda cudnn nccl tensorrt cutlass cutensor ];
    postBuild = ''
      for dir in lib lib64 include; do
        if [ -L "$out/$dir" ]; then
          target=$(readlink "$out/$dir")
          rm "$out/$dir"
          mkdir -p "$out/$dir"
          cp -rL "$target"/* "$out/$dir/" 2>/dev/null || true
        fi
      done
    '';
  };

in stdenv.mkDerivation {
  pname = "nvidia-sdk";
  version = versions.cuda.version;

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ merged ];

  installPhase = ''
    mkdir -p $out/{bin,lib64,include,nvvm,share,nix-support}

    for dir in bin lib lib64 include nvvm share; do
      if [ -e "${merged}/$dir" ]; then
        if [ -L "${merged}/$dir" ]; then
          target=$(readlink -f "${merged}/$dir")
          cp -rL "$target"/* "$out/$dir/" 2>/dev/null || true
        else
          cp -rL "${merged}/$dir"/* "$out/$dir/" 2>/dev/null || true
        fi
      fi
    done

    [ ! -e "$out/lib" ] && ln -sf lib64 $out/lib

    mkdir -p $out/lib64/stubs
    [ -d "${merged}/lib64/stubs" ] && cp -rL ${merged}/lib64/stubs/* $out/lib64/stubs/ 2>/dev/null || true

    cat > $out/nix-support/setup-hook << 'EOF'
    export CUDA_HOME="@out@"
    export CUDA_PATH="@out@"
    export CUDNN_HOME="@out@"
    export TENSORRT_HOME="@out@"
    export CUTLASS_PATH="@out@/include/cutlass"
    export PATH="@out@/bin:$PATH"
    export LD_LIBRARY_PATH="@out@/lib64:@out@/lib:$LD_LIBRARY_PATH"
    export LIBRARY_PATH="@out@/lib64:@out@/lib:$LIBRARY_PATH"
    export C_INCLUDE_PATH="@out@/include:$C_INCLUDE_PATH"
    export CPLUS_INCLUDE_PATH="@out@/include:$CPLUS_INCLUDE_PATH"
    export PKG_CONFIG_PATH="@out@/lib64/pkgconfig:$PKG_CONFIG_PATH"
    EOF
    sed -i "s|@out@|$out|g" $out/nix-support/setup-hook

    cat > $out/version.json << EOF
    {
      "cuda": "${versions.cuda.version}",
      "cudnn": "${versions.cudnn.version}",
      "nccl": "${versions.nccl.version}",
      "tensorrt": "${versions.tensorrt.version}",
      "cutlass": "${versions.cutlass.version}",
      "cutensor": "${versions.cutensor.version}"
    }
    EOF

    cat > $out/bin/nvidia-sdk-validate << 'VALIDATE'
    #!/bin/bash
    echo "NVIDIA SDK Components:"
    for lib in cudart cublas cufft curand cusolver cusparse nvrtc cudnn nccl nvinfer cutensor; do
      if ls @out@/lib64/lib$lib*.so* >/dev/null 2>&1; then
        echo "  ✓ $lib"
      else
        echo "  ✗ $lib"
      fi
    done
    echo ""
    cat @out@/version.json
    VALIDATE
    sed -i "s|@out@|$out|g" $out/bin/nvidia-sdk-validate
    chmod +x $out/bin/nvidia-sdk-validate

    mkdir -p $out/lib64/pkgconfig
    cat > $out/lib64/pkgconfig/nvidia-sdk.pc << PC
    prefix=$out
    libdir=\''${prefix}/lib64
    includedir=\''${prefix}/include

    Name: NVIDIA SDK
    Description: Unified NVIDIA CUDA development environment
    Version: ${versions.cuda.version}
    Libs: -L\''${libdir} -lcudart -lcudnn -lnccl -lnvinfer -lcutensor
    Cflags: -I\''${includedir}
    PC
  '';

  dontStrip = true;

  passthru = {
    inherit versions cuda cudnn nccl tensorrt cutlass cutensor;
    cudaVersion = versions.cuda.version;
    cudnnVersion = versions.cudnn.version;
  };

  meta = {
    description = "NVIDIA CUDA SDK ${versions.cuda.version}";
    homepage = "https://developer.nvidia.com/cuda-toolkit";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "nvcc";
  };
}
