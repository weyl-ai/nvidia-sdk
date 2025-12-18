# nvidia-redist

NVIDIA SDK redistribution for NixOS. NGC 25.11 blessed configuration for Blackwell (sm_120).

Supports x86_64-linux (intel) and aarch64-linux (grace).

## usage

```bash
# dev shell with full sdk
nix develop

# build individual components
nix build .#cuda
nix build .#cudnn
nix build .#nccl
nix build .#tensorrt
nix build .#cutensor
nix build .#cutlass
nix build .#nvidia-sdk      # unified sdk
nix build .#tritonserver    # inference server (from container)

# validate
nix run .#nvidia-sdk -- nvidia-sdk-validate
```

## as a flake input

```nix
{
  inputs.nvidia-redist.url = "github:yourorg/nvidia-redist";

  outputs = { self, nixpkgs, nvidia-redist }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ nvidia-redist.overlays.default ];
        config.allowUnfree = true;
      };
    in {
      # pkgs.nvidia-sdk, pkgs.cuda, pkgs.cudnn, etc now available
    };
}
```

## versions

Versions are defined in `nix/versions.nix`. No JSON manifests.

```bash
# check for updates
nix run .#update

# with r2 upload
UPLOAD_TO_R2=true R2_BUCKET=mybucket R2_ENDPOINT=https://xxx.r2.cloudflarestorage.com nix run .#update
```

## components

| package | version | source |
|---------|---------|--------|
| cuda | 13.0.2 | nvidia installer |
| cudnn | 9.17.0.29 | nvidia redist |
| nccl | 2.28.9 | ngc container |
| tensorrt | 10.14.1.48 | nvidia redist |
| cutensor | 2.4.1.4 | nvidia redist |
| cutlass | 3.8.0 | github |
| tritonserver | 25.11 | ngc container |

## architecture

- `nix/versions.nix` - version configuration (single source of truth)
- `nix/extract.nix` - extraction helpers
- `nix/cuda.nix` - cuda toolkit from nvidia installer
- `nix/cudnn.nix`, `nix/nccl.nix`, etc - individual components
- `nix/nvidia-sdk.nix` - unified sdk
- `nix/tritonserver.nix` - inference server from container
- `scripts/update.nix` - version update script with r2 upload
