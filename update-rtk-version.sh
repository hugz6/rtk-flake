#!/usr/bin/env bash
# update-rtk-version.sh
# Fetches the latest rtk release from GitHub, computes Nix SRI hashes
# for all 4 platforms, and updates flake.nix in-place.
#
# Usage:
#   ./update-rtk-version.sh          # auto-detect latest
#   ./update-rtk-version.sh v0.49.0  # specific version

set -euo pipefail

REPO="rtk-ai/rtk"
FLAKE_FILE="flake.nix"

#  Resolve version 
if [[ $# -ge 1 ]]; then
  TAG="$1"
else
  TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name"' | head -1 | cut -d'"' -f4)
fi

VERSION="${TAG#v}"  # strip leading 'v'

echo "==> Updating rtk to version ${VERSION} (tag ${TAG})"

CURRENT_VERSION=$(grep -oP 'version = "\K[^"]+' "$FLAKE_FILE" | head -1)
if [[ "$CURRENT_VERSION" == "$VERSION" ]]; then
  echo "==> Already at version ${VERSION}, nothing to do."
  exit 0
fi

declare -A ASSETS=(
  [x86_64-linux]="rtk-x86_64-unknown-linux-musl.tar.gz"
  [aarch64-linux]="rtk-aarch64-unknown-linux-gnu.tar.gz"
  [x86_64-darwin]="rtk-x86_64-apple-darwin.tar.gz"
  [aarch64-darwin]="rtk-aarch64-apple-darwin.tar.gz"
)

# Compute SRI hashes (raw tarball, NOT unpacked)
declare -A HASHES=()
for sys in "${!ASSETS[@]}"; do
  asset="${ASSETS[$sys]}"
  url="https://github.com/${REPO}/releases/download/${TAG}/${asset}"
  echo "  → Prefetching ${asset} ..."
  nix32=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null)
  sri=$(nix hash convert --hash-algo sha256 --to sri "$nix32")
  HASHES[$sys]="$sri"
  echo "    ${sys}: ${sri}"
done

# Patch flake.nix 
echo "==> Patching ${FLAKE_FILE} ..."

# Update version string
sed -i "s/version = \"${CURRENT_VERSION}\"/version = \"${VERSION}\"/" "$FLAKE_FILE"

# Update each platform hash
for sys in "${!HASHES[@]}"; do
  old_hash=$(
    awk -v sys="$sys" '
      $0 ~ sys" = {" { found=1 }
      found && /hash = "/ {
        match($0, /hash = "([^"]+)"/, m)
        print m[1]
        exit
      }
    ' "$FLAKE_FILE"
  )
  if [[ -n "$old_hash" ]]; then
    sed -i "s|${old_hash}|${HASHES[$sys]}|" "$FLAKE_FILE"
  fi
done

echo "==> Done! flake.nix updated to rtk ${VERSION}."
echo "    Run 'nix flake check' to verify."
