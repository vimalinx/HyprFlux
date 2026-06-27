#!/usr/bin/env bash
set -euo pipefail

mode="${1:-region}"
shot_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$shot_dir"

stamp="$(date '+%Y-%m-%d_%H-%M-%S')"
output="$shot_dir/Screenshot_${stamp}_${mode}.png"

case "$mode" in
  region)
    hyprshot -m region -z -r -s
    ;;
  window)
    hyprshot -m window -z -r -s
    ;;
  active)
    hyprshot -m active -m window -r -s
    ;;
  output)
    hyprshot -m output -z -r -s
    ;;
  *)
    notify-send -u low "Satty screenshot" "Unknown mode: $mode" || true
    exit 2
    ;;
esac | satty \
  --filename - \
  --output-filename "$output" \
  --copy-command wl-copy \
  --save-after-copy \
  --early-exit \
  --resize smart
