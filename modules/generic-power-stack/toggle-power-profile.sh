#!/usr/bin/env bash
# Cycle power profiles on non-ASUS machines.
# Prefers power-profiles-daemon; falls back to TLP when available.

set -euo pipefail

NOTIFICATION_TIMEOUT="${NOTIFICATION_TIMEOUT:-3000}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
LOCK_FILE="$RUNTIME_DIR/hyprflux-power-profile.lock"
LAST_RUN_FILE="$RUNTIME_DIR/hyprflux-power-profile.last"
DEBOUNCE_SECONDS="${PROFILE_DEBOUNCE_SECONDS:-2}"
MONITOR_CONFIG="${MONITOR_CONFIG:-$HOME/.config/hypr/monitors.conf}"
HIGH_HZ="${HIGH_REFRESH_HZ:-165}"
LOW_HZ="${LOW_REFRESH_HZ:-60}"

notify() {
  notify-send -t "$NOTIFICATION_TIMEOUT" "$@" || true
}

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

set_hypr_refresh() {
  local hz="$1"
  if ! command -v hyprctl >/dev/null 2>&1; then
    return 0
  fi
  local monitor mode
  monitor="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .name' | head -n1)"
  mode="$(hyprctl monitors -j 2>/dev/null | jq -r --arg m "$monitor" '.[] | select(.name==$m) | "\(.width)x\(.height)"' | head -n1)"
  if [[ -n "$monitor" && -n "$mode" && "$mode" != "null" ]]; then
    hyprctl keyword monitor "$monitor,$mode@$hz,auto,1" >/dev/null 2>&1 || true
  fi
  if [[ -f "$MONITOR_CONFIG" ]]; then
    # Best-effort: rewrite @Hz on the first active monitor line.
    sed -i -E "s/(@)[0-9]+(\.[0-9]+)?/\1${hz}/" "$MONITOR_CONFIG" 2>/dev/null || true
  fi
}

backend=""
current=""
if command -v powerprofilesctl >/dev/null 2>&1; then
  backend="ppd"
  current="$(powerprofilesctl get 2>/dev/null || true)"
elif command -v tlpctl >/dev/null 2>&1; then
  backend="tlp"
  current="$(tlpctl get 2>/dev/null || true)"
else
  notify -u critical "Power profile" "Need powerprofilesctl or tlpctl"
  exit 1
fi

case "$backend" in
  ppd)
    case "$current" in
      power-saver) next="balanced"; label="Balanced"; hz="$HIGH_HZ" ;;
      balanced) next="performance"; label="Performance"; hz="$HIGH_HZ" ;;
      performance) next="power-saver"; label="Power Saver"; hz="$LOW_HZ" ;;
      *) next="balanced"; label="Balanced"; hz="$HIGH_HZ" ;;
    esac
    powerprofilesctl set "$next"
    ;;
  tlp)
    case "$current" in
      power-saver) next="balanced"; label="Balanced"; hz="$HIGH_HZ" ;;
      balanced) next="performance"; label="Performance"; hz="$HIGH_HZ" ;;
      performance) next="power-saver"; label="Power Saver"; hz="$LOW_HZ" ;;
      *) next="balanced"; label="Balanced"; hz="$HIGH_HZ" ;;
    esac
    tlpctl set "$next"
    ;;
esac

set_hypr_refresh "$hz"
notify "Power profile" "$label ($backend)"
