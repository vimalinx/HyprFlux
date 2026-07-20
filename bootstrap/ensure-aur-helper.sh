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

hf_info "Installing yay (AUR helper bootstrap)"
if ! pacman -Qq base-devel >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm base-devel git <"$TTY_IN"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

rewrite_pkgbuild_github_mirrors() {
  local pkgbuild="$1"
  local mirror prefix
  [[ -f "$pkgbuild" ]] || return 0
  mirror="$(hf_pick_github_mirror)"
  [[ -n "$mirror" ]] || return 0
  # PKGBUILD source URLs are plain https://github.com/... ; rewrite to mirror prefix.
  if [[ "$mirror" == *"/https://github.com/" ]]; then
    prefix="$mirror"
  else
    prefix="$(hf_mirror_github_url "https://github.com/x/y" "$mirror")"
    prefix="${prefix%x/y.git}"
  fi
  if grep -q 'https://github.com/' "$pkgbuild"; then
    hf_info "Rewriting PKGBUILD GitHub URLs via mirror for China-friendly download"
    sed -i "s#https://github.com/#${prefix}#g" "$pkgbuild"
  fi
}

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
        rewrite_pkgbuild_github_mirrors "$dest/PKGBUILD"
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
  # Prefer this path when GitHub is slow: we control mirror downloads ourselves.
  local ver arch asset_arch asset url tdir
  arch="$(uname -m)"
  case "$arch" in
    x86_64) asset_arch="x86_64" ;;
    aarch64) asset_arch="aarch64" ;;
    *)
      hf_err "Unsupported arch for yay release bootstrap: $arch"
      return 1
      ;;
  esac

  ver="$(
    curl -fsSL --connect-timeout 5 --max-time 20 \
      https://api.github.com/repos/Jguer/yay/releases/latest 2>/dev/null \
      | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' \
      | head -n1
  )"
  if [[ -z "$ver" ]]; then
    # Keep in sync when bootstrap fails on an old pin.
    ver="v13.0.1"
    hf_warn "Could not resolve latest yay tag; falling back to $ver"
  fi
  ver="${ver#v}"
  asset="yay_${ver}_${asset_arch}.tar.gz"

  tdir="$work/yay-release"
  mkdir -p "$tdir"
  for url in \
    "https://ghfast.top/https://github.com/Jguer/yay/releases/download/v${ver}/${asset}" \
    "https://gh-proxy.com/https://github.com/Jguer/yay/releases/download/v${ver}/${asset}" \
    "https://mirror.ghproxy.com/https://github.com/Jguer/yay/releases/download/v${ver}/${asset}" \
    "https://github.com/Jguer/yay/releases/download/v${ver}/${asset}"
  do
    hf_info "Trying yay release: $url"
    if curl -fL --connect-timeout 8 --max-time 180 --retry 2 "$url" -o "$tdir/$asset"; then
      tar -xzf "$tdir/$asset" -C "$tdir"
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

# On China / blocked GitHub, prefer mirrored release binary first (avoids makepkg
# hanging on a direct github.com curl for 10+ minutes over a flaky SSH session).
prefer_release=0
if [[ "${HF_CN:-0}" == "1" ]] || ! hf_github_direct_ok; then
  prefer_release=1
fi

installed=0
if [[ "$prefer_release" == "1" ]]; then
  if install_yay_from_github_release; then
    hf_ok "yay installed from GitHub release into /usr/local/bin"
    installed=1
  else
    hf_warn "Release bootstrap failed — falling back to yay-bin makepkg"
  fi
fi

if [[ "$installed" != "1" ]]; then
  if clone_yay_bin "$work/yay"; then
    (
      cd "$work/yay"
      makepkg -si --noconfirm
    )
    installed=1
  elif [[ "$prefer_release" != "1" ]] && install_yay_from_github_release; then
    hf_ok "yay installed from GitHub release into /usr/local/bin"
    installed=1
  else
    hf_err "Failed to bootstrap yay (release + yay-bin all failed)"
    exit 1
  fi
fi

if ! command -v yay >/dev/null 2>&1; then
  hf_err "yay still not on PATH after install"
  exit 1
fi
hf_ok "yay installed ($(command -v yay))"
