# rtk-flake

Nix flake for [rtk](https://github.com/rtk-ai/rtk), a CLI proxy that reduces LLM token consumption by 60-90% on common dev commands.

## Features

- Pre-built binaries from GitHub releases (no Rust toolchain needed)
- Multi-platform: `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`
- Auto-update via GitHub Actions (daily check + PR)
- Build verified on CI before merging

## Usage

### Run directly

```bash
nix run github:hugz6/rtk-flake
```

### Install in a devShell / flake

```nix
{
  inputs.rtk-flake.url = "github:OWNER/rtk-flake";

  outputs = { self, nixpkgs, rtk-flake, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ rtk-flake.packages.${system}.rtk ];
      };
    };
}
```

### Use the overlay

```nix
{
  inputs.rtk-flake.url = "github:OWNER/rtk-flake";

  outputs = { self, nixpkgs, rtk-flake, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          nixpkgs.overlays = [ rtk-flake.overlays.default ];
          environment.systemPackages = [ pkgs.rtk ];
        }
      ];
    };
  };
}
```

### Install imperatively

```bash
nix profile install github:OWNER/rtk-flake#rtk
```

## Auto-update

A GitHub Actions workflow ([`.github/workflows/update-rtk.yml`](.github/workflows/update-rtk.yml)) runs daily and:

1. Checks the latest [rtk release](https://github.com/rtk-ai/rtk/releases)
2. If a new version is found, runs [`update-rtk-version.sh`](update-rtk-version.sh) to:
   - Prefetch all 4 platform tarballs
   - Compute SRI hashes
   - Patch `flake.nix` in-place
3. Updates `flake.lock`
4. Verifies the build with `nix build`
5. Opens a PR with the update

## Manual update

```bash
chmod +x update-rtk-version.sh
./update-rtk-version.sh          # latest release
./update-rtk-version.sh v0.49.0  # specific version
```

## License

MIT
