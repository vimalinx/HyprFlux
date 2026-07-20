#!/usr/bin/env bash
# Ensure yay or paru exists so AUR packages can be installed.
# Prefer yay-bin (has PKGBUILD). Do not clone Jguer/yay source — it no longer
# ships a root PKGBUILD, so makepkg fails with "PKGBUILD does not exist".
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/ui.sh"
# shellcheck source=/dev/null
source "$repo_root/scripts/net-china.sh"

TTY_IN="${HF_TTY:-/dev/tty}"
[[ -r "$TTY_IN" ]] || TTY_IN="/dev/stdin"

if command -v yay >/dev/null 2>&1 || command -v paru >/dev/null 2>&1; then
  hf_ok "AUR helper already present ($(command -v yay || command -v paru))"
  exit 0
fi

hf_info "Installing yay-bin (AUR helper bootstrap)"
if ! pacman -Qq base-devel >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm base-devel git <"$TTY_IN"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

clone_yay_bin() {
  local dest="$1"
  local url
  local candidates=(
    "https://aur.archlinux.org/yay-bin.git"
    "https://mirrors.tuna.tsinghua.edu.cn/git/aur.git/yay-bin"
    "https://mirrors.ustc.edu.cn/aur-git/yay-bin.git"
    "https://gitclone.com/aur.archlinux.org/yay-bin.git"
  )

  for url in "${candidates[@]}"; do
    hf_info "Trying yay-bin source: $url"
    rm -rf "$dest"
    if git clone --depth 1 "$url" "$dest"; then
      if [[ -f "$dest/PKGBUILD" ]]; then
        return 0
      fi
      hf_warn "Clone succeeded but PKGBUILD missing: $url"
    else
      hf_warn "Clone failed: $url"
    fi
  done
  return 1
}

install_yay_from_github_release() {
  # Last-resort binary bootstrap when AUR git is unreachable (common on some CN networks).
  local ver arch asset url tdir
  arch="$(uname -m)"
  case "$arch" in
    x86_64) asset_arch="x86_64" ;;
    aarch64) asset_arch="aarch64" ;;
    *)
      hf_err "Unsupported arch for yay release bootstrap: $arch"
      return 1
      ;;
  esac

  # Pin via GitHub latest redirect through mirrors when needed.
  ver="$(
    curl -fsSL https://api.github.com/repos/Jguer/yay/releases/latest \
      | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' \
      | head -n1
  )"
  if [[ -z "$ver" ]]; then
    # Mirror-friendly fallback: known recent tag; updated when bootstrap next fails.
    ver="v12.5.7"
    hf_warn "Could not resolve latest yay tag; falling back to $ver"
  fi
  ver="${ver#v}"
  asset="yay_${ver}_${asset_arch}.tar.gz"

  tdir="$work/yay-release"
  mkdir -p "$tdir"
  for url in \
    "https://github.com/Jguer/yay/releases/download/v${ver}/${asset}" \
    "https://ghfast.top/https://github.com/Jguer/yay/releases/download/v${ver}/${asset}" \
    "https://gh-proxy.com/https://github.com/Jguer/yay/releases/download/v${ver}/${asset}"
  do
    hf_info "Trying yay release: $url"
    if curl -fsSL "$url" -o "$tdir/$asset"; then
      tar -xzf "$tdir/$asset" -C "$tdir"
      # tarball usually contains yay_${ver}_${arch}/yay
      local bin
      bin="$(find "$tdir" -type f -name yay -perm -111 | head -n1)"
      if [[ -n "$bin" ]]; then
        sudo install -Dm755 "$bin" /usr/local/bin/yay <"$TTY_IN"
        return 0
      fi
      hf_warn "Release archive had no yay binary"
    else
      hf_warn "Release download failed: $url"
    fi
  done
  return 1
}

if clone_yay_bin "$work/yay"; then
  (
    cd "$work/yay"
    makepkg -si --noconfirm
  )
elif install_yay_from_github_release; then
  hf_ok "yay installed from GitHub release into /usr/local/bin"
else
  hf_err "Failed to bootstrap yay (AUR yay-bin + GitHub release all failed)"
  exit 1
fi

if ! command -v yay >/dev/null 2>&1; then
  hf_err "yay still not on PATH after install"
  exit 1
fi
hf_ok "yay installed ($(command -v yay))"
