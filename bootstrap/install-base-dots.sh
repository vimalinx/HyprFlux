#!/usr/bin/env bash
# Install JaKooLit Hyprland-Dots as the public desktop base, then leave room for HyprFlux overlays.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/ui.sh"

DOTS_URL="${HF_DOTS_URL:-https://github.com/JaKooLit/Hyprland-Dots.git}"
DOTS_REF="${HF_DOTS_REF:-main}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyprflux/Hyprland-Dots"

hf_section "Base dots (JaKooLit)"
hf_info "source: $DOTS_URL ($DOTS_REF)"

mkdir -p "$(dirname "$CACHE_DIR")"
if [[ -d "$CACHE_DIR/.git" ]]; then
  git -C "$CACHE_DIR" fetch --depth 1 origin "$DOTS_REF"
  git -C "$CACHE_DIR" checkout "$DOTS_REF"
  git -C "$CACHE_DIR" pull --ff-only origin "$DOTS_REF" || true
else
  rm -rf "$CACHE_DIR"
  git clone --depth 1 --branch "$DOTS_REF" "$DOTS_URL" "$CACHE_DIR"
fi

if [[ ! -d "$CACHE_DIR/config" ]]; then
  hf_err "Hyprland-Dots clone is missing config/"
  exit 1
fi

stamp="$(date +%Y%m%d-%H%M%S)"
backup_root="$HOME/.config/hyprflux-pre-dots-$stamp"
mkdir -p "$backup_root"

# Copy every top-level dots config tree into ~/.config, backing up collisions.
while IFS= read -r -d '' dir; do
  name="$(basename "$dir")"
  dest="$HOME/.config/$name"
  if [[ -e "$dest" ]]; then
    mkdir -p "$backup_root"
    cp -a "$dest" "$backup_root/$name"
    hf_info "backed up ~/.config/$name -> $backup_root/$name"
  fi
  mkdir -p "$dest"
  # Prefer rsync when available for cleaner updates.
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$dir/" "$dest/"
  else
    rm -rf "${dest:?}/"*
    cp -a "$dir/." "$dest/"
  fi
  hf_ok "installed base config: $name"
done < <(find "$CACHE_DIR/config" -mindepth 1 -maxdepth 1 -type d -print0)

# Ensure XDG dirs exist for a fresh Arch user.
xdg-user-dirs-update >/dev/null 2>&1 || true

hf_ok "JaKooLit base dots installed"
hf_info "backup of previous configs (if any): $backup_root"
