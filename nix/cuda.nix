{ lib, stdenv, buildFHSEnvBubblewrap, fetchurl, patchelf, file, libxml2, versions }:

let
  system = stdenv.hostPlatform.system;
  src-info = versions.cuda.${system} or (throw "cuda: unsupported system ${system}");

  libxml2-legacy = libxml2.overrideAttrs (old: rec {
    version = "2.9.14";
    src = fetchurl {
      url = "https://download.gnome.org/sources/libxml2/${lib.versions.majorMinor version}/libxml2-${version}.tar.xz";
      sha256 = "sha256-YNdKJX0czsBHXnScui8hVZ5IE577pv8oIkNXx8eY3+4=";
    };
  });

  fhs-env = buildFHSEnvBubblewrap {
    name = "cuda-installer-fhs";
    targetPkgs = pkgs: with pkgs; [
      coreutils curl file gcc glibc openssl
      patchelf perl util-linux which xz zlib
    ] ++ [ libxml2-legacy ];
  };

in stdenv.mkDerivation rec {
  pname = "cuda";
  version = versions.cuda.version;

  src = fetchurl {
    url = src-info.url;
    hash = src-info.hash;
  };

  nativeBuildInputs = [ fhs-env patchelf file ];
  buildInputs = [ stdenv.cc.cc.lib ];

  dontUnpack = true;
  dontConfigure = true;

  buildPhase = ''
    ${fhs-env}/bin/cuda-installer-fhs -c "
      sh $src --silent --toolkit --toolkitpath=$out --no-opengl-libs --override
    "
    [ ! -e $out/lib ] && ln -sf lib64 $out/lib || true
    mkdir -p $out/lib64/stubs
    [ -f $out/lib64/libcuda.so ] && mv $out/lib64/libcuda.so $out/lib64/stubs/ || true
  '';

  installPhase = ''
    mkdir -p $out/lib64/pkgconfig
    cat > $out/lib64/pkgconfig/cuda.pc << EOF
    prefix=$out
    libdir=\''${prefix}/lib64
    includedir=\''${prefix}/include

    Name: CUDA
    Description: NVIDIA CUDA Toolkit
    Version: ${version}
    Libs: -L\''${libdir} -lcudart
    Cflags: -I\''${includedir}
    EOF
  '';

  dontStrip = true;

  passthru = {
    inherit version;
    majorVersion = lib.versions.major version;
    inherit versions;
  };

  meta = {
    description = "NVIDIA CUDA Toolkit ${version}";
    homepage = "https://developer.nvidia.com/cuda-toolkit";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
