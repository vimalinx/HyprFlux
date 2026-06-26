#!/usr/bin/env bash
set -euo pipefail

battery_dir="$(find /sys/class/power_supply -maxdepth 1 -type l -name 'BAT*' | sort | head -n 1)"

if [ -z "$battery_dir" ]; then
  printf '{"text":"NoBat","tooltip":"No battery found","class":"unknown"}\n'
  exit 0
fi

charge_file="$battery_dir/charge_control_end_threshold"
capacity_file="$battery_dir/capacity"

if [ ! -r "$charge_file" ] || [ ! -r "$capacity_file" ]; then
  printf '{"text":"Err","tooltip":"Battery charge limit is not readable","class":"unknown"}\n'
  exit 0
fi

limit="$(cat "$charge_file")"
capacity="$(cat "$capacity_file")"
text="${capacity}/${limit}%"

case "$limit" in
  80)
    class_name="good"
    tooltip="Battery protection: 80% daily mode"
    ;;
  60)
    class_name="warning"
    tooltip="Battery protection: 60% long-life mode"
    ;;
  100)
    class_name="critical"
    tooltip="Battery protection: 100% full-charge mode"
    ;;
  *)
    class_name="info"
    tooltip="Battery charge limit: ${limit}%"
    ;;
esac

printf '{"text":"%s","tooltip":"%s","class":"%s","alt":"%s"}\n' "$text" "$tooltip" "$class_name" "$limit"
