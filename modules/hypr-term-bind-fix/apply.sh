#!/usr/bin/env bash
# Ensure $term exists before configs/Keybinds.conf and Super+Return uses a real terminal binary.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/ui.sh"

marker_term="# HyprFlux: terminal variables (before Keybinds)"
marker_keybinds="# HyprFlux terminal keybind overrides"
term_conf="$HOME/.config/hypr/UserConfigs/HyprFluxTerm.conf"
keybinds_overlay="$HOME/.config/hypr/UserConfigs/HyprFluxKeybinds.conf"
hyprland_conf="$HOME/.config/hypr/hyprland.conf"
user_keybinds="$HOME/.config/hypr/UserConfigs/UserKeybinds.conf"
user_defaults="$HOME/.config/hypr/UserConfigs/01-UserDefaults.conf"
dropterminal="$HOME/.config/hypr/scripts/Dropterminal.sh"

detect_terminal() {
  local candidate bin
  for candidate in kitty foot alacritty wezterm; do
    if bin="$(command -v "$candidate" 2>/dev/null)"; then
      printf '%s\n' "$bin"
      return 0
    fi
  done
  return 1
}

backup_once() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local bak="${f}.hyprflux-bak.$(date +%Y%m%d-%H%M%S)"
  cp -a "$f" "$bak"
  hf_ok "backup $f -> $bak"
}

term_bin="$(detect_terminal)" || {
  hf_warn "no terminal binary found (kitty/foot/alacritty/wezterm); skipping term bind fix"
  exit 0
}

mkdir -p "$(dirname "$term_conf")"

cat >"$term_conf" <<EOF
# HyprFlux terminal variables (sourced before configs/Keybinds.conf)
$marker_term
\$term = $term_bin
\$terminal = $term_bin
EOF
hf_ok "wrote UserConfigs/HyprFluxTerm.conf ($term_bin)"

if [[ -f "$hyprland_conf" ]]; then
  if grep -Fq "HyprFluxTerm.conf" "$hyprland_conf"; then
    if [[ "$(grep -cF 'HyprFluxTerm.conf' "$hyprland_conf")" -gt 1 ]]; then
      backup_once "$hyprland_conf"
      tmp="$(mktemp)"
      awk '!seen[$0]++ || !/HyprFluxTerm\.conf/' "$hyprland_conf" >"$tmp"
      mv "$tmp" "$hyprland_conf"
      hf_ok "removed duplicate HyprFluxTerm.conf source lines from hyprland.conf"
    fi
    hf_ok "hyprland.conf already sources HyprFluxTerm.conf"
  elif grep -qE '^[[:space:]]*source[[:space:]]*=.*(\$configs|configs)/Keybinds\.conf' "$hyprland_conf"; then
    backup_once "$hyprland_conf"
    sed -i -E '/^[[:space:]]*source[[:space:]]*=.*(\$configs|configs)\/Keybinds\.conf/i source = $HOME/.config/hypr/UserConfigs/HyprFluxTerm.conf # HyprFlux: term vars before Keybinds' \
      "$hyprland_conf"
    hf_ok "inserted early HyprFluxTerm.conf source before Keybinds.conf"
  else
    hf_warn "hyprland.conf has no Keybinds.conf source line; append HyprFluxTerm.conf near top"
    backup_once "$hyprland_conf"
    {
      printf '\n# HyprFlux: terminal variables before Keybinds\n'
      printf 'source = $HOME/.config/hypr/UserConfigs/HyprFluxTerm.conf\n'
    } >>"$hyprland_conf"
  fi
else
  hf_warn "hyprland.conf missing; HyprFluxTerm.conf is ready for next dots install"
fi

cat >"$keybinds_overlay" <<EOF
# HyprFlux terminal keybind overrides (absolute terminal path; loaded from UserKeybinds)
$marker_keybinds
bind = \$mainMod, Return, exec, uwsm app -- $term_bin
EOF

if [[ -x "$dropterminal" || -f "$dropterminal" ]]; then
  cat >>"$keybinds_overlay" <<EOF
bind = \$mainMod SHIFT, Return, exec, $dropterminal $term_bin
EOF
fi

hf_ok "wrote UserConfigs/HyprFluxKeybinds.conf (absolute terminal path)"

if [[ -f "$user_keybinds" ]]; then
  if grep -Fq "HyprFluxKeybinds.conf" "$user_keybinds"; then
    hf_ok "UserKeybinds.conf already sources HyprFluxKeybinds.conf"
  else
    backup_once "$user_keybinds"
    {
      printf '\n# HyprFlux keybind overrides\n'
      printf 'source = $UserConfigs/HyprFluxKeybinds.conf\n'
    } >>"$user_keybinds"
    hf_ok "appended HyprFluxKeybinds.conf source to UserKeybinds.conf"
  fi
else
  mkdir -p "$(dirname "$user_keybinds")"
  cat >"$user_keybinds" <<EOF
# HyprFlux keybind overrides
source = \$UserConfigs/HyprFluxKeybinds.conf
EOF
  hf_ok "created UserKeybinds.conf sourcing HyprFluxKeybinds.conf"
fi

if [[ -f "$user_defaults" ]]; then
  if grep -Eq '^\$term[[:space:]]*=' "$user_defaults"; then
    if grep -Fq "\$term = $term_bin" "$user_defaults"; then
      hf_ok "01-UserDefaults.conf already sets \$term to $term_bin"
    else
      backup_once "$user_defaults"
      sed -i -E "s|^\$term[[:space:]]*=.*|\$term = $term_bin # HyprFlux detected|" "$user_defaults"
      hf_ok "updated 01-UserDefaults.conf \$term -> $term_bin"
    fi
  fi
  if grep -Eq '^\$terminal[[:space:]]*=' "$user_defaults"; then
    sed -i -E "s|^\$terminal[[:space:]]*=.*|\$terminal = $term_bin # HyprFlux detected|" "$user_defaults" || true
  fi
fi
