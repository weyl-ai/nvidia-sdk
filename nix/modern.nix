# ╔════════════════════════════════════════════════════════════════════════════════╗
# ║  overlays/modern.nix                                                           ║
# ║  ────────────────────────────────────────────────────────────────────────────  ║
# ║  primitives for content-addressed builds                                       ║
# ║                                                                                ║
# ║  applicative laws hold:                                                        ║
# ║    1. identity:     pure id <*> v = v                                          ║
# ║    2. composition:  pure (.) <*> u <*> v <*> w = u <*> (v <*> w)               ║
# ║    3. homomorphism: pure f <*> pure x = pure (f x)                             ║
# ║    4. interchange:  u <*> pure y = pure ($ y) <*> u                            ║
# ╚════════════════════════════════════════════════════════════════════════════════╝

final: prev:
let
  lib = final.lib;

  # ════════════════════════════════════════════════════════════════════════════
  #  mk-runpath — construct ld runpath from dependencies
  # ════════════════════════════════════════════════════════════════════════════

  mk-runpath =
    deps:
    lib.concatStringsSep ":" (
      lib.concatMap (
        dep:
        let
          d = dep.lib or dep.out or dep;
        in
        [
          "${d}/lib"
          "${d}/lib64"
        ]
      ) deps
    );

  # ════════════════════════════════════════════════════════════════════════════
  #  patch-elf — fix interpreter and runpath for all ELFs
  # ════════════════════════════════════════════════════════════════════════════

  patch-elf =
    { runpath, out }:
    ''
      find ${out} -type f \( -executable -o -name "*.so*" \) 2>/dev/null | while read -r f; do
        if file "$f" | grep -q ELF; then
          if file "$f" | grep -q "executable"; then
            patchelf --set-interpreter "$(cat ${final.stdenv.cc}/nix-support/dynamic-linker)" "$f" 2>/dev/null || true
          fi
          existing=$(patchelf --print-rpath "$f" 2>/dev/null || echo "")
          new_rpath="${runpath}:${out}/lib:${out}/lib64''${existing:+:$existing}"
          patchelf --set-rpath "$new_rpath" "$f" 2>/dev/null || true
        fi
      done
    '';

  # ════════════════════════════════════════════════════════════════════════════
  #  mk-stub — create stub .so for build-time linking without driver
  # ════════════════════════════════════════════════════════════════════════════

  mk-stub =
    name: symbols:
    final.runCommand "${name}-stub" { } ''
      mkdir -p $out/lib
      cat > stub.c <<EOF
      ${lib.concatMapStringsSep "\n" (s: "void ${s}() {}") symbols}
      EOF
      ${final.gcc}/bin/gcc -shared -o $out/lib/${name} stub.c
    '';

in
{
  # Development stdenv: clang 21, C++23, no hardening, full debug symbols
  # Based on ps-v4/stellarwind toolchain - "connor grew a pair" edition
  devStdenv =
    let
      baseStdenv = prev.llvmPackages_21.stdenv.override {
        cc = prev.llvmPackages_21.stdenv.cc.override {
          gccForLibs = prev.gcc15.cc;
        };
      };
    in
    baseStdenv // {
      mkDerivation = args: baseStdenv.mkDerivation (args // {
      # No stripping - we want symbols for debugging, profiling, crash analysis
      dontStrip = true;
      separateDebugInfo = false;

      # Disable all hardening - fortification breaks CUDA, PIE/RELRO unnecessary for dev
      hardeningDisable = [ "all" ];

      # Allow /build/ references in RPATH - needed for debug info
      noAuditTmpdir = true;

      # Aggressive debug flags + disable fortification
      NIX_CFLAGS_COMPILE = (args.NIX_CFLAGS_COMPILE or "")
        + " -U_FORTIFY_SOURCE"
        + " -g3"  # maximum debug info
        + " -fno-omit-frame-pointer"  # for profiling
        + " -fno-limit-debug-info";  # full template debug info

      # C++23 by default
      NIX_CXXSTDLIB_COMPILE = (args.NIX_CXXSTDLIB_COMPILE or "") + " -std=c++23";
    });
  };

  modern = {
    inherit mk-runpath patch-elf mk-stub;

    # ══════════════════════════════════════════════════════════════════════════
    #  extract — unpack tarball/archive, patch rpaths
    # ══════════════════════════════════════════════════════════════════════════

    extract =
      {
        pname,
        version,
        src,
        runtime-inputs ? [ ],
        install ? "cp -a . $out/",
        post-install ? "",
        meta ? { },
        ...
      }:
      let
        runpath = mk-runpath runtime-inputs;
      in
      final.stdenv.mkDerivation {
        inherit
          pname
          version
          src
          meta
          ;

        nativeBuildInputs = [
          final.patchelf
          final.file
          final.gnutar
          final.gzip
          final.xz
          final.unzip
        ];

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
          ${patch-elf {
            inherit runpath;
            out = "$out";
          }}
          runHook postFixup
        '';
      };

    # ══════════════════════════════════════════════════════════════════════════
    #  wheel — python wheel to nix package
    # ══════════════════════════════════════════════════════════════════════════

    mk-wheel-package =
      {
        pname,
        version,
        src,
        python ? final.python312,
        python-deps ? [ ],
        runtime-inputs ? [ ],
        meta ? { },
      }:
      let
        runpath = mk-runpath (runtime-inputs ++ [ python ]);
      in
      python.pkgs.buildPythonPackage {
        inherit
          pname
          version
          src
          meta
          ;
        format = "wheel";
        propagatedBuildInputs = python-deps;
        nativeBuildInputs = [
          final.patchelf
          final.file
        ];

        postFixup = ''
          ${patch-elf {
            inherit runpath;
            out = "$out";
          }}
        '';
      };

    # ══════════════════════════════════════════════════════════════════════════
    #  container-to-nix — extract container filesystem (FOD)
    # ══════════════════════════════════════════════════════════════════════════

    container-to-nix =
      {
        name,
        imageRef,
        hash,
      }:
      final.stdenvNoCC.mkDerivation {
        inherit name;
        nativeBuildInputs = [
          final.crane
          final.gnutar
          final.gzip
        ];
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        outputHash = hash;
        SSL_CERT_FILE = "${final.cacert}/etc/ssl/certs/ca-bundle.crt";
        buildCommand = ''
          mkdir -p $out
          crane export ${imageRef} - | tar -xf - -C $out
        '';
      };

    # ══════════════════════════════════════════════════════════════════════════
    #  soname — stubs for build without driver
    # ══════════════════════════════════════════════════════════════════════════

    soname = {
      "libcuda.so.1" = mk-stub "libcuda.so.1" [
        "cuInit"
        "cuCtxCreate"
        "cuModuleLoad"
      ];

      "libnvidia-ml.so.1" = mk-stub "libnvidia-ml.so.1" [
        "nvmlInit"
        "nvmlDeviceGetCount"
      ];
    };
  };
}
