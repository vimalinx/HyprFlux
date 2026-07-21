#!/usr/bin/env bash
# Repair JaKooLit waybar config/style symlinks that still point at a stale template $HOME.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/ui.sh"

# JaKooLit dots sometimes ship symlinks for template user "ja".
readonly _HF_TEMPLATE_USER="ja"
readonly _HF_FOREIGN_HOME="/home/${_HF_TEMPLATE_USER}/"

waybar_dir="$HOME/.config/waybar"
configs_dir="$waybar_dir/configs"
style_dir="$waybar_dir/style"

symlink_broken_or_foreign() {
  local link="$1"
  [[ -L "$link" ]] || return 0
  local target
  target="$(readlink "$link" 2>/dev/null || true)"
  [[ -z "$target" ]] && return 0
  if [[ "$target" == *"${_HF_FOREIGN_HOME}"* ]]; then
    return 0
  fi
  [[ ! -e "$link" ]]
}

pick_config_layout() {
  local candidate
  for candidate in \
    "$configs_dir/[TOP] Default Laptop" \
    "$configs_dir/[TOP] Default" \
    "$configs_dir/[TOP] Simple"
    do
    if [[ -f "$candidate" || -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  shopt -s nullglob
  local matches=("$configs_dir/[TOP]"*)
  shopt -u nullglob
  if ((${#matches[@]} > 0)); then
    printf '%s\n' "${matches[0]}"
    return 0
  fi
  return 1
}

pick_style_file() {
  local candidate
  for candidate in \
    "$style_dir/[Wallust] Colored.css" \
    "$style_dir/[Colored] Translucent.css" \
    "$style_dir/[Dark] Wallust Colored.css" \
    "$style_dir/[Dark] Wallust Chroma Fusion Edge.css"
    do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  shopt -s nullglob
  local matches=("$style_dir/"*.css)
  shopt -u nullglob
  if ((${#matches[@]} > 0)); then
    printf '%s\n' "${matches[0]}"
    return 0
  fi
  return 1
}

repair_symlink() {
  local link="$1" target="$2"
  ln -sfn "$target" "$link"
  if [[ ! -r "$link" ]]; then
    hf_err "symlink still unreadable: $link -> $target"
    return 1
  fi
  hf_ok "$link -> $(readlink "$link")"
}

rewrite_ja_paths_in_scripts() {
  local dir script
  for dir in "$HOME/.config/waybar" "$HOME/.config/hypr/scripts"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' script; do
      if grep -qF "$_HF_FOREIGN_HOME" "$script" 2>/dev/null; then
        sed -i "s|${_HF_FOREIGN_HOME}|${HOME}/|g" "$script"
        hf_ok "rewrote stale template home paths in $(basename "$script")"
      fi
    done < <(find "$dir" -type f \( -name '*.sh' -o -name '*.py' \) -print0 2>/dev/null || true)
  done
}

mkdir -p "$waybar_dir"

if [[ ! -d "$configs_dir" ]]; then
  hf_warn "waybar configs dir missing ($configs_dir); skipping layout symlink repair"
else
  config_link="$waybar_dir/config"
  if symlink_broken_or_foreign "$config_link"; then
    layout="$(pick_config_layout)" || {
      hf_warn "no [TOP]* layout found under $configs_dir"
      layout=""
    }
    if [[ -n "$layout" ]]; then
      repair_symlink "$config_link" "$layout"
    fi
  else
    hf_ok "waybar config symlink already valid"
  fi
fi

if [[ ! -d "$style_dir" ]]; then
  hf_warn "waybar style dir missing ($style_dir); skipping style symlink repair"
else
  style_link="$waybar_dir/style.css"
  if symlink_broken_or_foreign "$style_link"; then
    style_file="$(pick_style_file)" || {
      hf_warn "no style/*.css found under $style_dir"
      style_file=""
    }
    if [[ -n "$style_file" ]]; then
      repair_symlink "$style_link" "$style_file"
    fi
  else
    hf_ok "waybar style.css symlink already valid"
  fi
fi

rewrite_ja_paths_in_scripts || true
