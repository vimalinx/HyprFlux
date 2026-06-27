#!/usr/bin/env bash
set -u

set_wallpaper="${SET_WALLPAPER_SCRIPT:-$HOME/.config/hypr/scripts/SetWallpaper.sh}"

[ -x "$set_wallpaper" ] || exit 0
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || exit 0

current_signature() {
  hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null | sort | paste -sd ',' -
}

last_signature="$(current_signature)"
"$set_wallpaper" >/dev/null 2>&1 || true

while sleep "${WALLPAPER_MONITOR_POLL:-2}"; do
  new_signature="$(current_signature)"
  [ "$new_signature" = "$last_signature" ] && continue
  last_signature="$new_signature"
  sleep 1
  "$set_wallpaper" >/dev/null 2>&1 || true
done
