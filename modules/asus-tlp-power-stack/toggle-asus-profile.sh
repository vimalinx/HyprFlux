#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_file="$script_dir/asus-profile.conf"

log_file="${XDG_CACHE_HOME:-$HOME/.cache}/asus-profile-toggle.log"
max_log_lines="${MAX_LOG_LINES:-100}"
notification_timeout="${NOTIFICATION_TIMEOUT:-3000}"
monitor_name="${MONITOR_NAME:-}"
monitor_mode="${MONITOR_MODE:-2560x1600}"
monitor_pos="${MONITOR_POS:-0x0}"
monitor_scale="${MONITOR_SCALE:-1.6}"

if [ -f "$config_file" ]; then
  # shellcheck source=/dev/null
  source "$config_file"
  max_log_lines="${MAX_LOG_LINES:-$max_log_lines}"
  notification_timeout="${NOTIFICATION_TIMEOUT:-$notification_timeout}"
  monitor_mode="${MONITOR_MODE:-$monitor_mode}"
  monitor_pos="${MONITOR_POS:-$monitor_pos}"
  monitor_scale="${MONITOR_SCALE:-$monitor_scale}"
fi

mkdir -p "$(dirname "$log_file")"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$log_file"
  if [ -f "$log_file" ] && [ "$(wc -l < "$log_file")" -gt "$max_log_lines" ]; then
    tail -n "$max_log_lines" "$log_file" > "${log_file}.tmp"
    mv "${log_file}.tmp" "$log_file"
  fi
}

notify() {
  notify-send -t "$notification_timeout" "$@" || true
}

current_tlp_profile() {
  tlpctl get 2>/dev/null || true
}

set_tlp_profile() {
  local profile="$1"
  local context="${2:-initial}"
  local readback

  [ -n "$profile" ] || return 2
  command -v tlpctl >/dev/null 2>&1 || return 2

  if tlpctl set "$profile" >> "$log_file" 2>&1; then
    readback="$(current_tlp_profile)"
    if [ "$readback" = "$profile" ]; then
      log "TLP profile set to $profile ($context)"
      return 0
    fi
    log "WARNING: TLP set $profile ($context) but read back ${readback:-unknown}"
    return 1
  fi

  log "ERROR: failed to set TLP profile $profile ($context)"
  return 1
}

schedule_quiet_tlp_reassert() {
  local profile="$1"
  local first_delay="${QUIET_TLP_REASSERT_DELAY:-2}"
  local late_delay="${QUIET_TLP_REASSERT_LATE_DELAY:-8}"

  [ "${QUIET_REASSERT_TLP:-1}" = "1" ] || return 0
  [ -n "$profile" ] || return 0
  command -v tlpctl >/dev/null 2>&1 || return 0

  (
    sleep "$first_delay"
    set_tlp_profile "$profile" "quiet-delayed-${first_delay}s" || true
    sleep "$late_delay"
    set_tlp_profile "$profile" "quiet-delayed-$((first_delay + late_delay))s" || true
  ) >/dev/null 2>&1 &
}

apply_quiet_runtime_tweaks() {
  local messages=()
  local iface

  if [ -n "${QUIET_BRIGHTNESS:-}" ] && command -v brightnessctl >/dev/null 2>&1; then
    if brightnessctl set "$QUIET_BRIGHTNESS" >> "$log_file" 2>&1; then
      messages+=("brightness: $QUIET_BRIGHTNESS")
    fi
  fi

  if [ "${QUIET_STOP_CAVA:-1}" = "1" ] && pgrep -x cava >/dev/null 2>&1; then
    if pkill -x cava >/dev/null 2>&1; then
      messages+=("cava: stopped")
    fi
  fi

  if [ "${QUIET_DISABLE_WWAN:-1}" = "1" ] && command -v nmcli >/dev/null 2>&1; then
    if nmcli radio wwan off >> "$log_file" 2>&1; then
      messages+=("WWAN: off")
    fi
  fi

  if [ "${QUIET_WIFI_POWERSAVE:-1}" = "1" ] && command -v iw >/dev/null 2>&1; then
    while IFS= read -r iface; do
      [ -n "$iface" ] || continue
      iw dev "$iface" set power_save on >> "$log_file" 2>&1 || true
    done < <(iw dev 2>/dev/null | awk '$1 == "Interface" { print $2 }')
    messages+=("Wi-Fi powersave: requested")
  fi

  if [ "${#messages[@]}" -gt 0 ]; then
    printf '%s\n' "${messages[@]}"
  fi
}

detect_monitor_name() {
  local detected=""

  if command -v jq >/dev/null 2>&1; then
    if [ -n "$monitor_name" ] && hyprctl monitors -j 2>/dev/null | jq -e --arg name "$monitor_name" '.[] | select(.name == $name)' >/dev/null; then
      printf '%s\n' "$monitor_name"
      return 0
    fi

    detected="$(
      hyprctl monitors -j 2>/dev/null |
        jq -r 'map(select(.name | test("^(eDP|LVDS|DSI)-"))) | .[0].name // empty'
    )"
    if [ -n "$detected" ]; then
      printf '%s\n' "$detected"
      return 0
    fi
  fi

  hyprctl monitors 2>/dev/null | awk '$1 == "Monitor" && $2 ~ /^(eDP|LVDS|DSI)-/ { print $2; exit }'
}

set_monitor_refresh() {
  local refresh_rate="$1"
  local name
  local target_mode

  command -v hyprctl >/dev/null 2>&1 || return 0
  name="$(detect_monitor_name)"
  [ -n "$name" ] || return 1

  target_mode="${monitor_mode}@${refresh_rate}"
  hyprctl keyword monitor "${name},${target_mode},${monitor_pos},${monitor_scale}" >/dev/null 2>&1
}

connected_bluetooth_count() {
  bluetoothctl devices Connected 2>/dev/null | awk '/^Device / { count++ } END { print count + 0 }'
}

autosuspend_bluetooth_if_idle() {
  local connected_count

  command -v bluetoothctl >/dev/null 2>&1 || return 0
  command -v rfkill >/dev/null 2>&1 || return 0
  bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' || return 0

  connected_count="$(connected_bluetooth_count)"
  if [ "$connected_count" -gt 0 ]; then
    printf 'Bluetooth: kept on (%s connected)\n' "$connected_count"
    return 0
  fi

  if rfkill block bluetooth >/dev/null 2>&1; then
    printf 'Bluetooth: off (idle)\n'
  fi
}

if ! command -v asusctl >/dev/null 2>&1; then
  notify -u critical "Power mode" "asusctl not found" -i dialog-error
  log "ERROR: asusctl not found"
  exit 1
fi

current="$(asusctl profile get | awk -F': ' '/Active profile/ { print $2; exit }')"
case "$current" in
  Quiet) next="Balanced" ;;
  Balanced) next="Performance" ;;
  Performance) next="Quiet" ;;
  *) next="Balanced" ;;
esac
log "ASUS profile current=$current next=$next"

case "$next" in
  Performance)
    icon="speedometer"
    tlp_profile="performance"
    led_level="high"
    blur="true"
    refresh_rate="240"
    mode_msg="Performance"
    ;;
  Balanced)
    icon="preferences-system-performance"
    tlp_profile="balanced"
    led_level="med"
    blur="true"
    refresh_rate="240"
    mode_msg="Balanced"
    ;;
  Quiet)
    icon="battery"
    tlp_profile="power-saver"
    led_level="low"
    blur="false"
    refresh_rate="60"
    mode_msg="Quiet"
    ;;
esac

tlp_msg="TLP: not synced"
if set_tlp_profile "$tlp_profile" "pre-asus"; then
  tlp_msg="TLP: $tlp_profile"
fi

if ! asusctl profile set "$next" 2>&1 | tee -a "$log_file"; then
  notify -u critical "Power mode" "Failed to switch ASUS profile" -i dialog-error
  log "ERROR: failed to set ASUS profile $next"
  exit 1
fi

if [ -n "${led_level:-}" ]; then
  asusctl leds set "$led_level" >/dev/null 2>&1 || true
fi

if [ -n "${blur:-}" ] && command -v hyprctl >/dev/null 2>&1; then
  hyprctl keyword decoration:blur:enabled "$blur" >/dev/null 2>&1 || true
fi

display_msg="Display: unchanged"
if [ -n "${refresh_rate:-}" ] && set_monitor_refresh "$refresh_rate"; then
  display_msg="Display: ${refresh_rate}Hz"
fi

quiet_tweaks_msg=""
bt_msg=""
if [ "$next" = "Quiet" ]; then
  if set_tlp_profile "$tlp_profile" "post-quiet"; then
    tlp_msg="TLP: $tlp_profile"
  fi
  schedule_quiet_tlp_reassert "$tlp_profile"
  quiet_tweaks_msg="$(apply_quiet_runtime_tweaks)"
  bt_msg="$(autosuspend_bluetooth_if_idle)"
fi

notify "Power mode" "Mode: $mode_msg
ASUS: $next
$tlp_msg
$display_msg${quiet_tweaks_msg:+
$quiet_tweaks_msg}${bt_msg:+
$bt_msg}" -i "$icon"
log "Notification sent"
