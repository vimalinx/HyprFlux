#!/usr/bin/env bash
# Cycle charge_control_end_threshold on non-ASUS machines: 80 -> 60 -> 100 -> 80.
# Requires write access to the sysfs file (often via a udev rule or pkexec helper).

set -euo pipefail

BAT="$(ls /sys/class/power_supply 2>/dev/null | grep -E '^BAT' | head -n1 || true)"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
LOCK_FILE="$RUNTIME_DIR/hyprflux-battery-limit.lock"
LAST_RUN_FILE="$RUNTIME_DIR/hyprflux-battery-limit.last"
DEBOUNCE_SECONDS=3

notify() {
  notify-send -t 3000 "$@" || true
}

if [[ -z "$BAT" ]]; then
  notify -u critical "Battery limit" "No BAT* power supply found"
  exit 1
fi

CHARGE_FILE="/sys/class/power_supply/$BAT/charge_control_end_threshold"
if [[ ! -e "$CHARGE_FILE" ]]; then
  notify -u critical "Battery limit" "$BAT has no charge_control_end_threshold"
  exit 1
fi

mkdir -p "$RUNTIME_DIR"
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

NOW="$(date +%s)"
LAST_RUN=0
if [[ -r "$LAST_RUN_FILE" ]]; then
  read -r LAST_RUN <"$LAST_RUN_FILE" || LAST_RUN=0
fi
if [[ "$LAST_RUN" =~ ^[0-9]+$ ]] && ((NOW - LAST_RUN < DEBOUNCE_SECONDS)); then
  exit 0
fi
printf '%s\n' "$NOW" >"$LAST_RUN_FILE"

CURRENT="$(cat "$CHARGE_FILE" 2>/dev/null || printf '80')"
case "$CURRENT" in
  80) NEW=60; ICON="battery-caution"; MSG="Long-plug protection (60%)" ;;
  60) NEW=100; ICON="battery-full"; MSG="Temporary full charge (100%)" ;;
  *) NEW=80; ICON="battery-good"; MSG="Daily protection (80%)" ;;
esac

write_limit() {
  local value="$1"
  if [[ -w "$CHARGE_FILE" ]]; then
    printf '%s\n' "$value" >"$CHARGE_FILE"
    return 0
  fi
  if command -v pkexec >/dev/null 2>&1; then
    pkexec /bin/sh -c "printf '%s\\n' '$value' >'$CHARGE_FILE'"
    return $?
  fi
  return 1
}

if ! write_limit "$NEW"; then
  notify -u critical "Battery limit" "Cannot write $CHARGE_FILE (need writable sysfs or pkexec)"
  exit 1
fi

REAL_VAL="$(cat "$CHARGE_FILE" 2>/dev/null || true)"
if [[ "$REAL_VAL" == "$NEW" ]]; then
  notify -u normal -i "$ICON" "Battery limit" "$MSG"
else
  notify -u critical "Battery limit" "Wrote $NEW% but read back ${REAL_VAL:-unknown}%"
  exit 1
fi
