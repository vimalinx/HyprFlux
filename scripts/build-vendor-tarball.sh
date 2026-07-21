#!/usr/bin/env bash
# Build site/public/vendor/HyprFlux-main.tar.gz for arch.vimalinx.com one-liner installs.
# Flat root: bootstrap/full.sh at tarball root (no HyprFlux-main/ prefix).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="$repo_root/site/public/vendor"
archive="$out_dir/HyprFlux-main.tar.gz"
sha_file="$archive.sha256"
staging="$(mktemp -d "${TMPDIR:-/tmp}/hyprflux-vendor.XXXXXX")"

cleanup() {
  rm -rf "$staging"
}
trap cleanup EXIT

includes=(
  bootstrap
  docs
  modules
  profiles
  scripts
  session
  install.sh
  LICENSE
  README.md
)

for item in "${includes[@]}"; do
  src="$repo_root/$item"
  [[ -e "$src" ]] || continue
  cp -a "$src" "$staging/"
done

mkdir -p "$out_dir"
tar -C "$staging" -czf "$archive" .

sha256sum "$archive" >"$sha_file"
# Normalize path in checksum file for site/public layout.
sed -i "s|  .*HyprFlux-main.tar.gz|  site/public/vendor/HyprFlux-main.tar.gz|" "$sha_file"

echo "Wrote $archive ($(wc -c <"$archive") bytes)"
echo "Wrote $sha_file"
cat "$sha_file"
