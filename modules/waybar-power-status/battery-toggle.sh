#!/usr/bin/env bash
set -euo pipefail

battery_dir="$(find /sys/class/power_supply -maxdepth 1 -type l -name 'BAT*' | sort | head -n 1)"
persist_file="${BATTERY_LIMIT_PERSIST_FILE:-/etc/battery_charge_limit}"

if [ -z "$battery_dir" ]; then
  notify-send -u critical "Battery limit" "No battery found" || true
  exit 1
fi

charge_file="$battery_dir/charge_control_end_threshold"
if [ ! -r "$charge_file" ]; then
  notify-send -u critical "Battery limit" "Charge limit file is not readable" || true
  exit 1
fi

current="$(cat "$charge_file" 2>/dev/null || echo 80)"

case "$current" in
  80)
    new_limit=60
    icon="battery-caution"
    message="Long-life mode (60%)"
    ;;
  60)
    new_limit=100
    icon="battery-full"
    message="Full-charge mode (100%)"
    ;;
  *)
    new_limit=80
    icon="battery-good"
    message="Daily mode (80%)"
    ;;
esac

pkexec bash -c 'printf "%s\n" "$1" > "$2"; printf "%s\n" "$1" > "$3"' bash "$new_limit" "$charge_file" "$persist_file"

real_value="$(cat "$charge_file" 2>/dev/null || echo unknown)"
if [ "$real_value" = "$new_limit" ]; then
  notify-send -u normal -i "$icon" "Battery limit" "$message" || true
else
  notify-send -u critical "Battery limit" "Requested $new_limit%, read back $real_value" || true
  exit 1
fi
