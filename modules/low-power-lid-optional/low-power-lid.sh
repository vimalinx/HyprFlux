#!/usr/bin/env bash
set -euo pipefail

log_file="${XDG_CACHE_HOME:-$HOME/.cache}/low-power-lid.log"
runtime_base="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/low-power-lid"
lock_file="$runtime_base/daemon.lock"
inhibitor_pid_file="$runtime_base/inhibitor.pid"
poll_interval="${LOW_POWER_LID_POLL_INTERVAL:-1}"
max_log_lines="${LOW_POWER_LID_MAX_LOG_LINES:-200}"

mkdir -p "$runtime_base" "$(dirname "$log_file")"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$log_file"
  if [ -f "$log_file" ] && [ "$(wc -l < "$log_file")" -gt "$max_log_lines" ]; then
    tail -n "$max_log_lines" "$log_file" > "${log_file}.tmp"
    mv "${log_file}.tmp" "$log_file"
  fi
}

lid_state_file() {
  if [ -n "${LOW_POWER_LID_STATE_FILE:-}" ] && [ -r "$LOW_POWER_LID_STATE_FILE" ]; then
    printf '%s\n' "$LOW_POWER_LID_STATE_FILE"
    return 0
  fi

  find /proc/acpi/button/lid -mindepth 2 -maxdepth 2 -name state -readable -print -quit 2>/dev/null || true
}

lid_state() {
  local state_file
  state_file="$(lid_state_file)"
  if [ -z "$state_file" ]; then
    printf 'unknown\n'
    return 0
  fi

  awk '{ print $2 }' "$state_file" 2>/dev/null || printf 'unknown\n'
}

tlp_profile() {
  command -v tlpctl >/dev/null 2>&1 || return 0
  tlpctl get 2>/dev/null || true
}

asus_profile() {
  command -v asusctl >/dev/null 2>&1 || return 0
  asusctl profile get 2>/dev/null | awk -F': ' '/Active profile/ { print $2; exit }'
}

platform_profile() {
  [ -r /sys/firmware/acpi/platform_profile ] || return 0
  cat /sys/firmware/acpi/platform_profile 2>/dev/null || true
}

is_low_power_profile() {
  local tlp asus platform

  tlp="$(tlp_profile)"
  asus="$(asus_profile)"
  platform="$(platform_profile)"

  [ "$tlp" = "power-saver" ] || [ "$asus" = "Quiet" ] || [ "$platform" = "quiet" ]
}

inhibitor_pid() {
  [ -r "$inhibitor_pid_file" ] || return 1
  cat "$inhibitor_pid_file"
}

inhibitor_alive() {
  local pid
  pid="$(inhibitor_pid 2>/dev/null || true)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

start_inhibitor() {
  if inhibitor_alive; then
    return 0
  fi

  rm -f "$inhibitor_pid_file"
  systemd-inhibit \
    --what=handle-lid-switch \
    --mode=block \
    --why="Low-power lid mode keeps Hyprland running while the lid is closed" \
    sleep infinity >> "$log_file" 2>&1 &
  printf '%s\n' "$!" > "$inhibitor_pid_file"
  sleep 0.1

  if inhibitor_alive; then
    log "Started handle-lid-switch inhibitor pid=$(cat "$inhibitor_pid_file")"
  else
    log "ERROR: failed to start handle-lid-switch inhibitor"
    rm -f "$inhibitor_pid_file"
    return 1
  fi
}

stop_inhibitor() {
  local pid
  pid="$(inhibitor_pid 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    log "Stopped handle-lid-switch inhibitor pid=$pid"
  fi
  rm -f "$inhibitor_pid_file"
}

internal_monitor_name() {
  if command -v jq >/dev/null 2>&1; then
    hyprctl monitors -j 2>/dev/null |
      jq -r 'map(select(.name | test("^(eDP|LVDS|DSI)-"))) | .[0].name // empty' |
      sed -n '1p'
    return 0
  fi

  hyprctl monitors 2>/dev/null | awk '$1 == "Monitor" && $2 ~ /^(eDP|LVDS|DSI)-/ { print $2; exit }'
}

set_internal_refresh_60() {
  command -v hyprctl >/dev/null 2>&1 || return 0
  command -v jq >/dev/null 2>&1 || return 0

  local spec
  spec="$(
    hyprctl monitors -j 2>/dev/null |
      jq -r '
        map(select(.name | test("^(eDP|LVDS|DSI)-"))) | .[0] // empty
        | select(.availableModes[]? | test("@60\\.00Hz$"))
        | "\(.name),\(.width)x\(.height)@60,\(.x)x\(.y),\(.scale)"
      ' |
      sed -n '1p'
  )"

  [ -n "$spec" ] || return 0
  hyprctl keyword monitor "$spec" >/dev/null 2>&1 || true
}

set_dpms() {
  local action="$1"
  local monitor

  command -v hyprctl >/dev/null 2>&1 || return 0
  monitor="$(internal_monitor_name)"

  if [ -n "$monitor" ]; then
    hyprctl dispatch dpms "$action" "$monitor" >/dev/null 2>&1 ||
      hyprctl dispatch dpms "$action" >/dev/null 2>&1 ||
      true
  else
    hyprctl dispatch dpms "$action" >/dev/null 2>&1 || true
  fi
}

apply_low_power_lid_state() {
  if command -v tlpctl >/dev/null 2>&1 && [ "$(tlp_profile)" != "power-saver" ]; then
    tlpctl set power-saver >> "$log_file" 2>&1 || log "WARNING: failed to set TLP power-saver"
  fi

  if command -v asusctl >/dev/null 2>&1 && [ "$(asus_profile)" != "Quiet" ]; then
    asusctl profile set Quiet >> "$log_file" 2>&1 || log "WARNING: failed to set ASUS Quiet"
  fi

  if command -v asusctl >/dev/null 2>&1; then
    asusctl leds set low >/dev/null 2>&1 || true
  fi

  set_internal_refresh_60
  set_dpms off
}

print_status() {
  local low_power="no"
  local inhibitor="no"

  if is_low_power_profile; then
    low_power="yes"
  fi
  if inhibitor_alive; then
    inhibitor="yes pid=$(cat "$inhibitor_pid_file")"
  fi

  printf 'lid=%s\n' "$(lid_state)"
  printf 'low_power=%s\n' "$low_power"
  printf 'inhibitor=%s\n' "$inhibitor"
  printf 'tlp=%s\n' "$(tlp_profile)"
  printf 'asus=%s\n' "$(asus_profile)"
  printf 'platform=%s\n' "$(platform_profile)"
}

daemon() {
  exec 9>"$lock_file"
  if ! flock -n 9; then
    log "Another low-power lid daemon is already running"
    exit 0
  fi

  local last_lid=""
  local lid=""
  local lid_low_power_active=0

  trap 'stop_inhibitor; exit 0' INT TERM EXIT
  log "Daemon started"

  while true; do
    lid="$(lid_state)"

    if is_low_power_profile; then
      start_inhibitor || true

      if [ "$lid" = "closed" ]; then
        apply_low_power_lid_state
        if [ "$lid_low_power_active" != "1" ]; then
          log "Lid closed in low-power profile: DPMS off, system kept running"
        fi
        lid_low_power_active=1
      elif [ "$lid" = "open" ]; then
        if [ "$lid_low_power_active" = "1" ]; then
          set_dpms on
          log "Lid opened after low-power close: DPMS on"
        fi
        lid_low_power_active=0
      fi
    else
      stop_inhibitor
      if [ "$lid" = "open" ] && [ "$lid_low_power_active" = "1" ]; then
        set_dpms on
      fi
      lid_low_power_active=0
    fi

    if [ "$lid" != "$last_lid" ]; then
      log "Lid state: $lid"
      last_lid="$lid"
    fi

    sleep "$poll_interval"
  done
}

case "${1:---daemon}" in
  --daemon)
    daemon
    ;;
  --status)
    print_status
    ;;
  --ensure-inhibitor)
    if is_low_power_profile; then
      start_inhibitor
    else
      stop_inhibitor
    fi
    print_status
    ;;
  --dpms-on)
    set_dpms on
    ;;
  --dpms-off)
    apply_low_power_lid_state
    ;;
  *)
    printf 'Usage: %s [--daemon|--status|--ensure-inhibitor|--dpms-on|--dpms-off]\n' "$0" >&2
    exit 2
    ;;
esac
