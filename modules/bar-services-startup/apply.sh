#!/usr/bin/env bash
# Hand bar + notification startup to systemd; disable JaKooLit exec-once duplicates.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/ui.sh"

backup_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local bak="${f}.hyprflux-bak.$(date +%Y%m%d-%H%M%S)"
  cp -a "$f" "$bak"
  hf_ok "backup $f -> $bak"
}

comment_exec_once() {
  local file="$1"
  local pattern="$2"
  [[ -f "$file" ]] || return 0
  if grep -Eq "^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*${pattern}[[:space:]]*$" "$file"; then
    sed -i -E "s|^[[:space:]]*(exec-once[[:space:]]*=[[:space:]]*${pattern}[[:space:]]*)$|# HyprFlux: systemd owns this service\n# \\1|" "$file"
    hf_ok "disabled exec-once ${pattern} in $(basename "$file")"
  fi
}

startup_candidates=(
  "$HOME/.config/hypr/configs/Startup_Apps.conf"
  "$HOME/.config/hypr/UserConfigs/Startup_Apps.conf"
)

for startup_file in "${startup_candidates[@]}"; do
  if [[ -f "$startup_file" ]]; then
    backup_file "$startup_file"
    comment_exec_once "$startup_file" 'waybar'
    comment_exec_once "$startup_file" 'swaync'
  fi
done

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload || true
  for unit in swaync.service waybar.service; do
    if systemctl --user cat "$unit" >/dev/null 2>&1; then
      if systemctl --user enable "$unit" >/dev/null 2>&1 \
        && systemctl --user restart "$unit" >/dev/null 2>&1; then
        hf_ok "enabled and restarted $unit"
      else
        hf_warn "$unit enable/restart failed (retry after next Hyprland login)"
      fi
    else
      hf_info "$unit not installed; leaving Hyprland/manual startup as fallback"
    fi
  done
fi
