# primitives for binary package extraction
{ lib, stdenv, stdenvNoCC, patchelf, file, gnutar, gzip, xz, unzip, crane, cacert }:

let
  mk-runpath = deps:
    lib.concatStringsSep ":" (
      lib.concatMap (dep:
        let d = dep.lib or dep.out or dep;
        in [ "${d}/lib" "${d}/lib64" ]
      ) deps
    );

  patch-elf = { runpath, out }:
    ''
      find ${out} -type f \( -executable -o -name "*.so*" \) 2>/dev/null | while read -r f; do
        [ -L "$f" ] && continue
        file "$f" | grep -q ELF || continue
        if file "$f" | grep -q "executable"; then
          patchelf --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" "$f" 2>/dev/null || true
        fi
        existing=$(patchelf --print-rpath "$f" 2>/dev/null || echo "")
        new_rpath="${runpath}:${out}/lib:${out}/lib64''${existing:+:$existing}"
        patchelf --set-rpath "$new_rpath" "$f" 2>/dev/null || true
      done
    '';

in {
  inherit mk-runpath patch-elf;

  extract = { pname, version, src, runtime-inputs ? [], install ? "cp -a . $out/", post-install ? "", meta ? {} }:
    let runpath = mk-runpath runtime-inputs;
    in stdenv.mkDerivation {
      inherit pname version src meta;
      nativeBuildInputs = [ patchelf file gnutar gzip xz unzip ];
      dontConfigure = true;
      dontBuild = true;
      dontUnpack = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out
        ${install}
        ${post-install}
        runHook postInstall
      '';
      fixupPhase = ''
        runHook preFixup
        ${patch-elf { inherit runpath; out = "$out"; }}
        runHook postFixup
      '';
    };

  container-to-nix = { name, image-ref, hash }:
    stdenvNoCC.mkDerivation {
      inherit name;
      nativeBuildInputs = [ crane gnutar gzip ];
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash = hash;
      SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
      buildCommand = ''
        mkdir -p $out
        crane export ${image-ref} - | tar -xf - -C $out
      '';
    };

  mk-stub = name: symbols:
    stdenv.mkDerivation {
      pname = "${name}-stub";
      version = "1.0";
      dontUnpack = true;
      nativeBuildInputs = [ stdenv.cc ];
      buildPhase = ''
        cat > stub.c <<EOF
        ${lib.concatMapStringsSep "\n" (s: "void ${s}() {}") symbols}
        EOF
        $CC -shared -o ${name} stub.c
      '';
      installPhase = ''
        mkdir -p $out/lib
        cp ${name} $out/lib/
      '';
    };
}
