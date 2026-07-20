#!/usr/bin/env bash
# Ensure yay or paru exists so AUR packages can be installed.
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

hf_info "Installing yay from GitHub (needs sudo + base-devel)"
if ! pacman -Qq base-devel >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm base-devel git <"$TTY_IN"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Prefer GitHub source via mirrors (more reliable in China than aur.archlinux.org sometimes).
if ! hf_git_clone_github "https://github.com/Jguer/yay.git" "$work/yay" --depth 1; then
  hf_warn "GitHub yay clone failed — trying aur.archlinux.org"
  if ! git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$work/yay"; then
    hf_err "Failed to fetch yay sources"
    exit 1
  fi
fi

(
  cd "$work/yay"
  # Source tree uses makepkg; yay-bin package dir also works with makepkg -si.
  makepkg -si --noconfirm
)
hf_ok "yay installed"
