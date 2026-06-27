#!/usr/bin/env bash
set -u

image="${1:-$HOME/.config/hypr/wallpaper_effects/.wallpaper_current}"

if [ ! -f "$image" ]; then
  echo "SetWallpaper: image not found: $image" >&2
  exit 1
fi

if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  swww-daemon --format xrgb >/dev/null 2>&1 &
  sleep 0.8
fi

monitors="$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)"
if [ -n "$monitors" ]; then
  while IFS= read -r monitor; do
    [ -n "$monitor" ] || continue
    swww img -o "$monitor" "$image" >/dev/null 2>&1 || true
  done <<< "$monitors"
else
  swww img "$image" >/dev/null 2>&1 || true
fi

ln -sfn "$image" "$HOME/.config/rofi/.current_wallpaper"
mkdir -p "$HOME/.config/hypr/wallpaper_effects"
cp -f "$image" "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
