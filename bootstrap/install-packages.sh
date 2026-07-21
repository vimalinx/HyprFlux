#!/usr/bin/env bash
# Install package lists with pacman / AUR helper.
# Resolves official-list drift (renames / AUR moves) before pacman -S so one
# missing name cannot abort the whole desktop bootstrap.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/ui.sh"

TTY_IN="$(hf_sudo_in)"

profile="${1:-generic}"
include_optional="${2:-0}"
[[ "${HF_OPTIONAL:-0}" == "1" ]] && include_optional=1
official_list="$repo_root/bootstrap/packages-official.txt"
aur_list="$repo_root/bootstrap/packages-aur.txt"
aur_optional_list="$repo_root/bootstrap/packages-aur-optional.txt"
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
if [[ "$include_optional" == "1" ]]; then
  mapfile -t AUR_OPT < <(read_pkgs "$aur_optional_list")
  if [[ ${#AUR_OPT[@]} -gt 0 ]]; then
    AUR+=("${AUR_OPT[@]}")
    hf_info "Including optional AUR packages (${#AUR_OPT[@]})"
  fi
else
  hf_ok "Skipping optional AUR (quickshell-git). Pass --with-optional / HF_OPTIONAL=1 to include."
fi
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
  aur_cache_clear() {
    local name="$1"
    local cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
    rm -rf "${cache_home}/yay/${name}" "${cache_home}/paru/clone/${name}" 2>/dev/null || true
  }

  aur_install_one() {
    local pkg="$1"
    if pkg_installed "$pkg"; then
      hf_ok "Already installed: $pkg"
      return 0
    fi
    hf_info "AUR: $pkg"
    if "$aur_helper" -S --needed --noconfirm "$pkg" <"$TTY_IN"; then
      return 0
    fi
    hf_warn "AUR package failed — clearing build cache and retrying once: $pkg"
    aur_cache_clear "$pkg"
    if "$aur_helper" -S --needed --noconfirm "$pkg" <"$TTY_IN"; then
      hf_ok "AUR retry succeeded: $pkg"
      return 0
    fi
    hf_warn "AUR package failed (continuing): $pkg"
    return 1
  }

  hf_info "Installing AUR packages with $aur_helper (one-by-one for resilience)"
  for pkg in "${AUR[@]}"; do
    aur_install_one "$pkg" || true
  done
fi

ensure_swww_compat_symlinks
hf_ok "Package stage complete"
