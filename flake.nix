{
  description = "Nix flake for rtk (LLM token consumption reducer)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      version = "1.2.0";

      platforms = {
        x86_64-linux = {
          asset = "rtk-x86_64-unknown-linux-musl.tar.gz";
          hash = "sha256-cP7ntKVIxD3elMd+IzVVCYGwvC+wE2kdjIEJtb0O2jc=";
        };
        aarch64-linux = {
          asset = "rtk-aarch64-unknown-linux-gnu.tar.gz";
          hash = "sha256-k8Hc03/V/K6Pp3KltcNKMK8UKs5PQIHI+YMZFGt6EKQ=";
        };
        x86_64-darwin = {
          asset = "rtk-x86_64-apple-darwin.tar.gz";
          hash = "sha256-FISub//Q2hgNZUNO7KMuAUqGpuIdz8egAE/oK3uwqbk=";
        };
        aarch64-darwin = {
          asset = "rtk-aarch64-apple-darwin.tar.gz";
          hash = "sha256-osQR/6SahZW0CMFR6kfJqBImiSSnbq7svDpQZbAiB/8=";
        };
      };
    in
    flake-utils.lib.eachSystem (builtins.attrNames platforms) (system:
      let
        pkgs = import nixpkgs { inherit system; };
        platInfo = platforms.${system};

        src = pkgs.fetchurl {
          url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/${platInfo.asset}";
          hash = platInfo.hash;
        };

        isLinux = pkgs.lib.hasSuffix "-linux" system;

        rtk = pkgs.stdenv.mkDerivation {
          pname = "rtk";
          inherit version src;

          dontUnpack = true;

          nativeBuildInputs = [
            pkgs.gnutar
            pkgs.gzip
          ] ++ pkgs.lib.optionals isLinux [
            pkgs.autoPatchelfHook
          ];

          buildInputs = pkgs.lib.optionals isLinux [
            pkgs.stdenv.cc.cc.lib  # libstdc++ / libgcc_s
          ];

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin
            tar xzf $src
            # The tarball extracts the 'rtk' binary at the root
            if [ -f rtk ]; then
              install -m755 rtk $out/bin/rtk
            else
              # Fallback: find in any subdirectory
              find . -name 'rtk' -type f -executable | head -1 | xargs -I{} install -m755 {} $out/bin/rtk
            fi

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "CLI proxy that reduces LLM token consumption by 60-90% on common dev commands";
            homepage = "https://github.com/rtk-ai/rtk";
            license = licenses.mit;
            mainProgram = "rtk";
            platforms = builtins.attrNames platforms;
          };
        };
      in
      {
        packages = {
          rtk = rtk;
          default = rtk;
        };

        apps.default = {
          type = "app";
          program = "${rtk}/bin/rtk";
        };
      }
    ) // {
      # Top-level overlay (usable without specifying a system)
      overlays.default = final: prev: {
        rtk = self.packages.${prev.stdenv.hostPlatform.system}.rtk;
      };
    };
}
