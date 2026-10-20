#!/usr/bin/env bash
# ============================================================
# FILMCRAFT auto-updater (mirrors pkgs/photocraft-update.sh)
# ============================================================
# Checks GitHub for a new FilmCraft release and, if found,
# bumps `version` + `hash` in pkgs/filmcraft.nix (the tarball URL
# is interpolated from `version`, so nothing else moves).
#
# The new hash comes from `nix store prefetch-file` AND is
# cross-checked against upstream's published SHA256SUMS.txt —
# both must agree or the update aborts.
#
# Usage:
#   ./pkgs/filmcraft-update.sh            # check + update file only
#   ./pkgs/filmcraft-update.sh --switch   # ... then nixos-rebuild switch
set -euo pipefail

REPO="storytold/filmcraft"
NIX_FILE="/etc/nixos/pkgs/filmcraft.nix"
ASSET_TMPL="filmcraft-%s-linux-x86_64.tar.gz"

current="$(grep -oP '^\s*version = "\K[^"]+' "$NIX_FILE" | head -1)"
echo "installed pin: $current"

tag="$(curl -fsSL --retry 3 "https://api.github.com/repos/$REPO/releases/latest" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"
latest="${tag#v}"
echo "upstream latest: $latest ($tag)"

if [[ "$latest" == "$current" ]]; then
  echo "already up to date."
  exit 0
fi

# shellcheck disable=SC2059
asset="$(printf "$ASSET_TMPL" "$latest")"
url="https://github.com/$REPO/releases/download/v$latest/$asset"
echo "new release found — prefetching $asset ..."

prefetch_json="$(nix store prefetch-file --json "$url")"
new_hash="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["hash"])' <<<"$prefetch_json")"
echo "store hash: $new_hash"

# Cross-check against upstream's published checksums.
echo "cross-checking against upstream SHA256SUMS.txt ..."
sums_hex="$(curl -fsSL --retry 3 "https://github.com/$REPO/releases/download/v$latest/SHA256SUMS.txt" \
  | grep -F "  $asset" | awk '{print $1}')"
if [[ -z "$sums_hex" ]]; then
  echo "ERROR: $asset not listed in upstream SHA256SUMS.txt — aborting." >&2
  exit 1
fi
sums_sri="$(python3 -c 'import base64,sys; print("sha256-"+base64.b64encode(bytes.fromhex(sys.argv[1].strip())).decode())' "$sums_hex")"
if [[ "$sums_sri" != "$new_hash" ]]; then
  echo "ERROR: hash mismatch! store=$new_hash sums.txt=$sums_sri — aborting." >&2
  exit 1
fi
echo "checksums agree."

sed -i \
  -e "s|^\(\s*\)version = \"$current\";|\1version = \"$latest\";|" \
  -e "s|^\(\s*\)hash = \"sha256-[A-Za-z0-9+/=]*\";|\1hash = \"$new_hash\";|" \
  "$NIX_FILE"
git -C /etc/nixos add "$NIX_FILE"
echo "pkgs/filmcraft.nix bumped $current -> $latest and staged."

if [[ "${1:-}" == "--switch" ]]; then
  sudo nixos-rebuild switch --flake /etc/nixos#nixos
else
  echo "next: nix-test && nix-switch   (or re-run with --switch)"
fi
