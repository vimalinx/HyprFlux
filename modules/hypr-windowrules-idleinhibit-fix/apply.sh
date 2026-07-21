#!/usr/bin/env bash
# Remove JaKooLit WindowRules lines that break Hyprland 0.56 (^(*)$ regex).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/ui.sh"

rules_file="$HOME/.config/hypr/configs/WindowRules.conf"
marker="# HyprFlux idle_inhibit fullscreen (Hyprland 0.56+)"
block_file="$HOME/.config/hypr/UserConfigs/HyprFluxWindowRules.conf"

if [[ ! -f "$rules_file" ]]; then
  hf_warn "WindowRules.conf missing; skipping idle_inhibit fix"
  exit 0
fi

if grep -q '\^\(\*\)\$' "$rules_file"; then
  bak="${rules_file}.hyprflux-bak.$(date +%Y%m%d-%H%M%S)"
  cp -a "$rules_file" "$bak"
  sed -i '/\^(\*)\$/d' "$rules_file"
  hf_ok "removed invalid ^(*)$ windowrule lines from WindowRules.conf"
fi

mkdir -p "$(dirname "$block_file")"
if [[ ! -f "$block_file" ]] || ! grep -Fq "$marker" "$block_file"; then
  cat >>"$block_file" <<EOF

$marker
windowrule {
  name = hyprflux-idle-inhibit-fullscreen
  idle_inhibit = fullscreen
  match:fullscreen = 1
}
EOF
  hf_ok "appended Hyprland 0.56 idle_inhibit rule to UserConfigs/HyprFluxWindowRules.conf"
fi

user_rules="$HOME/.config/hypr/UserConfigs/WindowRules.conf"
if [[ -f "$user_rules" ]] && ! grep -Fq "HyprFluxWindowRules.conf" "$user_rules"; then
  bak="${user_rules}.hyprflux-bak.$(date +%Y%m%d-%H%M%S)"
  cp -a "$user_rules" "$bak"
  {
    printf '\n# HyprFlux window rule overrides\n'
    printf 'source = $UserConfigs/HyprFluxWindowRules.conf\n'
  } >>"$user_rules"
  hf_ok "sourced HyprFluxWindowRules.conf from UserConfigs/WindowRules.conf"
elif [[ ! -f "$user_rules" ]]; then
  mkdir -p "$(dirname "$user_rules")"
  cat >"$user_rules" <<EOF
# HyprFlux window rule overrides
source = \$UserConfigs/HyprFluxWindowRules.conf
EOF
  hf_ok "created UserConfigs/WindowRules.conf sourcing HyprFlux overrides"
fi
