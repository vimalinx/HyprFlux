#!/usr/bin/env bash
# Ensure yay or paru exists so AUR packages can be installed.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/ui.sh"

TTY_IN="${HF_TTY:-/dev/tty}"
[[ -r "$TTY_IN" ]] || TTY_IN="/dev/stdin"

if command -v yay >/dev/null 2>&1 || command -v paru >/dev/null 2>&1; then
  hf_ok "AUR helper already present ($(command -v yay || command -v paru))"
  exit 0
fi

hf_info "Installing yay-bin from the AUR (needs sudo + base-devel)"
if ! pacman -Qq base-devel >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm base-devel git <"$TTY_IN"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$work/yay-bin"
(
  cd "$work/yay-bin"
  makepkg -si --noconfirm
)
hf_ok "yay installed"
