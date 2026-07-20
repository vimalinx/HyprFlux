#!/usr/bin/env bash
# Install package lists with pacman / AUR helper.
# Resolves official-list drift (renames / AUR moves) before pacman -S so one
# missing name cannot abort the whole desktop bootstrap.
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

pkg_in_sync() {
  pacman -Si -- "$1" >/dev/null 2>&1
}

pkg_installed() {
  pacman -Qq -- "$1" >/dev/null 2>&1
}

ensure_swww_compat_symlinks() {
  # awww replaces swww but keeps different binary names; JaKooLit scripts still call swww*.
  if command -v awww >/dev/null 2>&1 && ! command -v swww >/dev/null 2>&1; then
    hf_info "Creating swww → awww compatibility symlinks in /usr/local/bin"
    sudo ln -sfn "$(command -v awww)" /usr/local/bin/swww <"$TTY_IN"
  fi
  if command -v awww-daemon >/dev/null 2>&1 && ! command -v swww-daemon >/dev/null 2>&1; then
    sudo ln -sfn "$(command -v awww-daemon)" /usr/local/bin/swww-daemon <"$TTY_IN"
  fi
}

mapfile -t OFFICIAL_RAW < <(read_pkgs "$official_list")
mapfile -t AUR < <(read_pkgs "$aur_list")
ASUS_RAW=()
if [[ "$profile" == "asus" ]]; then
  mapfile -t ASUS_RAW < <(read_pkgs "$asus_list")
fi

hf_section "Packages"

# Arch partial upgrades break the Hyprland stack (soname bumps on hyprutils /
# aquamarine). Bootstrap always syncs DBs then upgrades the system before the
# desktop package set, so dependencies resolve in one consistent generation.
hf_info "Syncing pacman databases and upgrading system (-Syu)"
sudo pacman -Syu --noconfirm <"$TTY_IN"

OFFICIAL=()
ASUS=()
for pkg in "${OFFICIAL_RAW[@]}"; do
  if pkg_in_sync "$pkg" || pkg_installed "$pkg"; then
    OFFICIAL+=("$pkg")
  else
    hf_warn "Not in official repos — will try AUR: $pkg"
    AUR+=("$pkg")
  fi
done
for pkg in "${ASUS_RAW[@]}"; do
  if pkg_in_sync "$pkg" || pkg_installed "$pkg"; then
    ASUS+=("$pkg")
  else
    hf_warn "ASUS package not in official repos — will try AUR: $pkg"
    AUR+=("$pkg")
  fi
done

# De-duplicate AUR list while preserving order.
if [[ ${#AUR[@]} -gt 0 ]]; then
  declare -A _seen=()
  AUR_DEDUP=()
  for pkg in "${AUR[@]}"; do
    [[ -n "${_seen[$pkg]:-}" ]] && continue
    _seen["$pkg"]=1
    AUR_DEDUP+=("$pkg")
  done
  AUR=("${AUR_DEDUP[@]}")
  unset _seen
fi

hf_info "official: ${#OFFICIAL[@]}  aur: ${#AUR[@]}  asus-extra: ${#ASUS[@]}"

if [[ ${#OFFICIAL[@]} -gt 0 || ${#ASUS[@]} -gt 0 ]]; then
  hf_info "Installing official packages"
  # shellcheck disable=SC2068
  sudo pacman -S --needed --noconfirm ${OFFICIAL[@]+"${OFFICIAL[@]}"} ${ASUS[@]+"${ASUS[@]}"} <"$TTY_IN"
fi

ensure_swww_compat_symlinks

"$repo_root/bootstrap/ensure-aur-helper.sh"
aur_helper="$(command -v yay || command -v paru)"
if [[ ${#AUR[@]} -gt 0 ]]; then
  hf_info "Installing AUR packages with $aur_helper"
  # Prefer skipping already-installed packages; continue on optional AUR failures.
  if ! "$aur_helper" -S --needed --noconfirm "${AUR[@]}" <"$TTY_IN"; then
    hf_warn "Batch AUR install had failures — retrying packages one by one"
    for pkg in "${AUR[@]}"; do
      if pkg_installed "$pkg"; then
        continue
      fi
      if ! "$aur_helper" -S --needed --noconfirm "$pkg" <"$TTY_IN"; then
        hf_warn "AUR package failed (continuing): $pkg"
      fi
    done
  fi
fi

ensure_swww_compat_symlinks
hf_ok "Package stage complete"
