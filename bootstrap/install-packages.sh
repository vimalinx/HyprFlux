#!/usr/bin/env bash
# Install package lists with pacman / AUR helper.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/ui.sh"

TTY_IN="${HF_TTY:-/dev/tty}"
[[ -r "$TTY_IN" ]] || TTY_IN="/dev/stdin"

profile="${1:-generic}"
official_list="$repo_root/bootstrap/packages-official.txt"
aur_list="$repo_root/bootstrap/packages-aur.txt"
asus_list="$repo_root/bootstrap/packages-asus.txt"

read_pkgs() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    printf '%s\n' "$line"
  done <"$file"
}

mapfile -t OFFICIAL < <(read_pkgs "$official_list")
mapfile -t AUR < <(read_pkgs "$aur_list")
ASUS=()
if [[ "$profile" == "asus" ]]; then
  mapfile -t ASUS < <(read_pkgs "$asus_list")
fi

hf_section "Packages"
hf_info "official: ${#OFFICIAL[@]}  aur: ${#AUR[@]}  asus-extra: ${#ASUS[@]}"

hf_info "Refreshing pacman databases"
sudo pacman -Sy --noconfirm <"$TTY_IN"

hf_info "Installing official packages"
# shellcheck disable=SC2068
sudo pacman -S --needed --noconfirm ${OFFICIAL[@]} ${ASUS[@]} <"$TTY_IN"

"$repo_root/bootstrap/ensure-aur-helper.sh"
aur_helper="$(command -v yay || command -v paru)"
if [[ ${#AUR[@]} -gt 0 ]]; then
  hf_info "Installing AUR packages with $aur_helper"
  # Prefer skipping already-installed packages; continue on optional AUR failures.
  if ! "$aur_helper" -S --needed --noconfirm "${AUR[@]}" <"$TTY_IN"; then
    hf_warn "Some AUR packages failed; continuing with the rest of the bootstrap"
  fi
fi

hf_ok "Package stage complete"
