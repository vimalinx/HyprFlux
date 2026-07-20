#!/usr/bin/env bash
# Cycle the ASUS firmware charge limit: 80 -> 60 -> 100 -> 80.

set -euo pipefail

BAT="BAT1"
CHARGE_FILE="/sys/class/power_supply/$BAT/charge_control_end_threshold"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
LOCK_FILE="$RUNTIME_DIR/asus-battery-limit.lock"
LAST_RUN_FILE="$RUNTIME_DIR/asus-battery-limit.last"
DEBOUNCE_SECONDS=3

notify() {
    notify-send -t 3000 "$@" || true
}

mkdir -p "$RUNTIME_DIR"

if ! command -v asusctl >/dev/null 2>&1 || ! command -v flock >/dev/null 2>&1; then
    notify -u critical "Battery limit" "asusctl or flock is missing"
    exit 1
fi

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

NOW="$(date +%s)"
LAST_RUN=0
if [ -r "$LAST_RUN_FILE" ]; then
    read -r LAST_RUN < "$LAST_RUN_FILE" || LAST_RUN=0
fi
if [[ "$LAST_RUN" =~ ^[0-9]+$ ]] && [ "$((NOW - LAST_RUN))" -lt "$DEBOUNCE_SECONDS" ]; then
    exit 0
fi
printf '%s\n' "$NOW" > "$LAST_RUN_FILE"

CURRENT="$(cat "$CHARGE_FILE" 2>/dev/null || printf '80')"
case "$CURRENT" in
    80)
        NEW=60
        ICON="battery-caution"
        MSG="Long-plug protection (60%)"
        ;;
    60)
        NEW=100
        ICON="battery-full"
        MSG="Temporary full charge (100%)"
        ;;
    *)
        NEW=80
        ICON="battery-good"
        MSG="Daily protection (80%)"
        ;;
esac

# asusd owns persistence and the firmware interface, so no root shell or
# parallel /etc state file is needed.
if ! asusctl battery limit "$NEW" >/dev/null 2>&1; then
    notify -u critical "Battery limit" "Failed to switch to ${NEW}%"
    exit 1
fi

for _ in {1..20}; do
    REAL_VAL="$(cat "$CHARGE_FILE" 2>/dev/null || true)"
    [ "$REAL_VAL" = "$NEW" ] && break
    sleep 0.1
done

if [ "${REAL_VAL:-}" = "$NEW" ]; then
    notify -u normal -i "$ICON" "Battery limit" "$MSG"
else
    notify -u critical "Battery limit" "ASUS accepted the request, but read-back is ${REAL_VAL:-unknown}%"
    exit 1
fi
