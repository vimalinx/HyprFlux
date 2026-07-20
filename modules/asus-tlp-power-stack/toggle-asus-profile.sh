#!/usr/bin/env bash
# Toggle ASUS platform profile and sync the matching TLP profile.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/asus-profile.conf"

LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/asus-profile-toggle.log"
MAX_LOG_LINES=100
NOTIFICATION_TIMEOUT=3000
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
LOCK_FILE="$RUNTIME_DIR/asus-profile-toggle.lock"
LAST_RUN_FILE="$RUNTIME_DIR/asus-profile-toggle.last"
MONITOR_NAME="${MONITOR_NAME:-}"
MONITOR_MODE="${MONITOR_MODE:-2560x1600}"
MONITOR_POS="${MONITOR_POS:-0x0}"
MONITOR_SCALE="${MONITOR_SCALE:-1.6}"
MONITOR_CONFIG="${MONITOR_CONFIG:-$HOME/.config/hypr/monitors.conf}"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

mkdir -p "$(dirname "$LOG_FILE")" "$RUNTIME_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
    if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt "$MAX_LOG_LINES" ]; then
        tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
}

notify() {
    notify-send -t "$NOTIFICATION_TIMEOUT" "$@" || true
}

current_tlp_profile() {
    tlpctl get 2>/dev/null || true
}

set_tlp_profile() {
    local profile="$1"
    local context="${2:-post-asus}"
    local readback=""
    local attempt
    local attempts="${TLP_SYNC_ATTEMPTS:-30}"
    local interval="${TLP_SYNC_INTERVAL:-0.2}"

    if [ -z "$profile" ] || ! command -v tlpctl >/dev/null 2>&1; then
        return 2
    fi

    if tlpctl set "$profile" >> "$LOG_FILE" 2>&1; then
        for ((attempt = 1; attempt <= attempts; attempt++)); do
            readback="$(current_tlp_profile)"
            if [ "$readback" = "$profile" ]; then
                log "TLP profile set to: $profile ($context, attempt $attempt)"
                return 0
            fi
            sleep "$interval"
        done

        readback="$(current_tlp_profile)"
        log "WARNING: TLP set $profile ($context) but timed out; read back: ${readback:-unknown}"
        return 1
    fi

    log "ERROR: failed to set TLP profile: $profile ($context)"
    return 1
}

apply_quiet_runtime_tweaks() {
    local messages=()
    local iface

    if [ -n "${QUIET_BRIGHTNESS:-}" ] && command -v brightnessctl >/dev/null 2>&1; then
        if brightnessctl set "$QUIET_BRIGHTNESS" >> "$LOG_FILE" 2>&1; then
            messages+=("亮度: $QUIET_BRIGHTNESS")
            log "Quiet brightness set to: $QUIET_BRIGHTNESS"
        else
            log "ERROR: failed to set quiet brightness: $QUIET_BRIGHTNESS"
        fi
    fi

    if [ "${QUIET_STOP_CAVA:-1}" = "1" ] && pgrep -x cava >/dev/null 2>&1; then
        if pkill -x cava >/dev/null 2>&1; then
            messages+=("cava: 已停止")
            log "Quiet stopped cava"
        else
            log "ERROR: failed to stop cava"
        fi
    fi

    if [ "${QUIET_DISABLE_WWAN:-1}" = "1" ] && command -v nmcli >/dev/null 2>&1; then
        if nmcli radio wwan off >> "$LOG_FILE" 2>&1; then
            messages+=("WWAN: off")
            log "Quiet disabled WWAN radio"
        else
            log "ERROR: failed to disable WWAN radio"
        fi
    fi

    if [ "${QUIET_WIFI_POWERSAVE:-1}" = "1" ] && command -v iw >/dev/null 2>&1; then
        while IFS= read -r iface; do
            [ -n "$iface" ] || continue
            if iw dev "$iface" get power_save 2>/dev/null | grep -q 'Power save: on'; then
                messages+=("Wi-Fi省电: $iface")
                log "Quiet Wi-Fi powersave already on for $iface"
            elif iw dev "$iface" set power_save on >> "$LOG_FILE" 2>&1; then
                messages+=("Wi-Fi省电: $iface")
                log "Quiet enabled Wi-Fi powersave on $iface"
            else
                log "WARNING: failed to enable Wi-Fi powersave on $iface; TLP may already manage it"
            fi
        done < <(iw dev 2>/dev/null | awk '$1 == "Interface" { print $2 }')
    fi

    if [ "${#messages[@]}" -gt 0 ]; then
        printf '%s\n' "${messages[@]}"
    fi
}

detect_monitor_name() {
    local configured="${MONITOR_NAME:-}"
    local detected=""

    if command -v jq >/dev/null 2>&1; then
        if [ -n "$configured" ] && hyprctl monitors -j 2>/dev/null | jq -e --arg name "$configured" '.[] | select(.name == $name)' >/dev/null; then
            printf '%s\n' "$configured"
            return 0
        fi

        detected="$(
            hyprctl monitors -j 2>/dev/null \
                | jq -r 'map(select(.name | test("^(eDP|LVDS|DSI)-"))) | .[0].name // empty'
        )"
        if [ -n "$detected" ]; then
            printf '%s\n' "$detected"
            return 0
        fi

        detected="$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].name // empty')"
        if [ -n "$detected" ]; then
            printf '%s\n' "$detected"
            return 0
        fi
    fi

    hyprctl monitors 2>/dev/null \
        | awk '$1 == "Monitor" && $2 ~ /^(eDP|LVDS|DSI)-/ { print $2; exit }'
}

set_monitor_refresh() {
    local refresh_rate="$1"
    local monitor_name monitor_description
    local target_mode="${MONITOR_MODE}@${refresh_rate}"
    local tmp_file current_refresh

    monitor_name="$(detect_monitor_name)"
    if [ -z "$monitor_name" ]; then
        log "ERROR: no Hyprland monitor detected"
        return 1
    fi

    monitor_description="$(
        hyprctl monitors -j 2>/dev/null \
            | jq -r --arg name "$monitor_name" '.[] | select(.name == $name) | .description // empty'
    )"

    # Persist the internal panel mode in nwg-displays' owner file, while
    # preserving position, scale, bit depth, and all external monitor lines.
    if [ -w "$MONITOR_CONFIG" ] && [ -n "$monitor_description" ]; then
        tmp_file="$(mktemp "${MONITOR_CONFIG}.XXXXXX")"
        if awk -v prefix="monitor=desc:${monitor_description}," -v mode="${target_mode}.0" '
            index($0, prefix) == 1 {
                suffix = substr($0, length(prefix) + 1)
                comma = index(suffix, ",")
                if (comma > 0) {
                    suffix = mode substr(suffix, comma)
                    $0 = prefix suffix
                    matched = 1
                }
            }
            { print }
            END { if (!matched) exit 3 }
        ' "$MONITOR_CONFIG" > "$tmp_file"; then
            chmod --reference="$MONITOR_CONFIG" "$tmp_file"
            mv "$tmp_file" "$MONITOR_CONFIG"
        else
            rm -f "$tmp_file"
            log "WARNING: internal monitor entry not found in $MONITOR_CONFIG"
        fi
    fi

    hyprctl keyword monitor "${monitor_name},${target_mode},${MONITOR_POS},${MONITOR_SCALE}" >/dev/null 2>&1 || return 1

    sleep 1
    current_refresh="$(
        hyprctl monitors 2>/dev/null \
            | awk -v name="$monitor_name" '
                $1 == "Monitor" && $2 == name {
                    found = 1
                    next
                }
                found && $1 ~ /^[0-9]+x[0-9]+@/ {
                    split($1, parts, "@")
                    print int(parts[2] + 0)
                    exit
                }
            '
    )"
    [ "$current_refresh" = "$refresh_rate" ]
}

connected_bluetooth_count() {
    bluetoothctl devices Connected 2>/dev/null | awk '/^Device / { count++ } END { print count + 0 }'
}

autosuspend_bluetooth_if_idle() {
    local connected_count

    if ! command -v bluetoothctl >/dev/null 2>&1 || ! command -v rfkill >/dev/null 2>&1; then
        printf '蓝牙: 未检测\n'
        log "Bluetooth autosuspend skipped: missing bluetoothctl or rfkill"
        return 0
    fi

    if ! bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
        printf '蓝牙: 已关闭\n'
        log "Bluetooth already powered off"
        return 0
    fi

    connected_count="$(connected_bluetooth_count)"
    if [ "$connected_count" -gt 0 ]; then
        printf '蓝牙: %s 个设备连接，保持开启\n' "$connected_count"
        log "Bluetooth kept on: $connected_count connected device(s)"
        return 0
    fi

    if rfkill block bluetooth >/dev/null 2>&1; then
        printf '蓝牙: 未连接，已关闭\n'
        log "Bluetooth blocked because no devices are connected"
    else
        printf '蓝牙: 关闭失败\n'
        log "ERROR: failed to block idle bluetooth"
    fi
}

normalize_profile() {
    case "${1,,}" in
        performance) printf 'Performance\n' ;;
        balanced) printf 'Balanced\n' ;;
        quiet) printf 'Quiet\n' ;;
        *) return 1 ;;
    esac
}

TARGET_PROFILE=""
FORCE=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --set)
            [ "$#" -ge 2 ] || { printf '用法: %s [--set Quiet|Balanced|Performance] [--force]\n' "$0" >&2; exit 2; }
            TARGET_PROFILE="$(normalize_profile "$2")" || { printf '未知档位: %s\n' "$2" >&2; exit 2; }
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --help|-h)
            printf '用法: %s [--set Quiet|Balanced|Performance] [--force]\n' "$0"
            exit 0
            ;;
        *)
            printf '未知参数: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

if ! command -v flock >/dev/null 2>&1; then
    notify -u critical "Power mode" "flock not found; cannot switch safely" -i dialog-error
    log "ERROR: flock not found"
    exit 1
fi

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    log "Skipped duplicate trigger: another profile switch is running"
    exit 0
fi

# The ASUS Fn key can emit duplicate events a few seconds apart. Only debounce
# cyclic hotkey calls; explicit --set calls remain deterministic for recovery.
if [ -z "$TARGET_PROFILE" ] && [ "$FORCE" -ne 1 ]; then
    NOW="$(date +%s)"
    LAST_RUN=0
    if [ -r "$LAST_RUN_FILE" ]; then
        read -r LAST_RUN < "$LAST_RUN_FILE" || LAST_RUN=0
    fi
    if [[ "$LAST_RUN" =~ ^[0-9]+$ ]] && [ "$((NOW - LAST_RUN))" -lt "${PROFILE_DEBOUNCE_SECONDS:-4}" ]; then
        log "Skipped duplicate trigger inside ${PROFILE_DEBOUNCE_SECONDS:-4}s debounce window"
        exit 0
    fi
    printf '%s\n' "$NOW" > "$LAST_RUN_FILE"
fi

if ! command -v asusctl >/dev/null 2>&1; then
    notify -u critical "Power mode" "asusctl not found" -i dialog-error
    log "ERROR: asusctl not found"
    exit 1
fi

CURRENT="$(asusctl profile get | awk -F': ' '/Active profile/ {print $2}')"
if [ -n "$TARGET_PROFILE" ]; then
    NEXT="$TARGET_PROFILE"
else
    case "$CURRENT" in
        Quiet) NEXT="Balanced" ;;
        Balanced) NEXT="Performance" ;;
        Performance) NEXT="Quiet" ;;
        *) NEXT="Balanced" ;;
    esac
fi
log "ASUS profile current: $CURRENT, next: $NEXT"

case "$NEXT" in
    Performance)
        ICON="speedometer"
        TLP_PROFILE="performance"
        LED_LEVEL="high"
        BLUR="true"
        REFRESH_RATE="240"
        MODE_MSG="性能"
        ;;
    Balanced)
        ICON="preferences-system-performance"
        TLP_PROFILE="balanced"
        LED_LEVEL="med"
        BLUR="true"
        REFRESH_RATE="240"
        MODE_MSG="平衡"
        ;;
    Quiet)
        ICON="battery"
        TLP_PROFILE="power-saver"
        LED_LEVEL="low"
        BLUR="false"
        REFRESH_RATE="60"
        MODE_MSG="省电"
        ;;
    *)
        ICON="battery"
        TLP_PROFILE=""
        LED_LEVEL=""
        BLUR=""
        REFRESH_RATE=""
        MODE_MSG="$CURRENT"
        log "WARNING: unknown ASUS profile: $CURRENT"
        ;;
esac

if ! {
    asusctl profile set -a "$NEXT" \
        && asusctl profile set -b "$NEXT" \
        && asusctl profile set "$NEXT"
} 2>&1 | tee -a "$LOG_FILE"; then
    notify -u critical "Power mode" "Failed to switch ASUS profile" -i dialog-error
    log "ERROR: failed to set ASUS profile: $NEXT"
    exit 1
fi
log "ASUS profile set to: $NEXT (active, AC default, battery default)"

TLP_MSG="TLP 未同步"
if [ -n "$TLP_PROFILE" ] && command -v tlpctl >/dev/null 2>&1; then
    if set_tlp_profile "$TLP_PROFILE" "post-asus"; then
        TLP_MSG="TLP: $TLP_PROFILE"
    else
        TLP_MSG="TLP 同步失败"
    fi
fi

if [ -n "$LED_LEVEL" ]; then
    asusctl leds set "$LED_LEVEL" >/dev/null 2>&1 || true
fi

DISPLAY_MSG="屏幕未调整"
if [ -n "$REFRESH_RATE" ] && command -v hyprctl >/dev/null 2>&1; then
    if set_monitor_refresh "$REFRESH_RATE"; then
        DISPLAY_MSG="屏幕: ${REFRESH_RATE}Hz"
        log "Monitor refresh set to ${MONITOR_MODE}@${REFRESH_RATE}"
    else
        DISPLAY_MSG="屏幕切换失败"
        log "ERROR: failed to set monitor to ${MONITOR_MODE}@${REFRESH_RATE}"
    fi
fi

# Apply visual policy after the monitor update so a compositor/config refresh
# cannot overwrite the selected profile's blur setting.
if [ -n "$BLUR" ]; then
    hyprctl keyword decoration:blur:enabled "$BLUR" >/dev/null 2>&1 || true
fi

BT_MSG=""
QUIET_TWEAKS_MSG=""
if [ "$NEXT" = "Quiet" ]; then
    QUIET_TWEAKS_MSG="$(apply_quiet_runtime_tweaks)"
    if [ "${QUIET_AUTOSUSPEND_BLUETOOTH:-0}" = "1" ]; then
        BT_MSG="$(autosuspend_bluetooth_if_idle)"
    fi
fi

notify "Power mode" "Switched to: $MODE_MSG\nASUS: $NEXT\n$TLP_MSG\n$DISPLAY_MSG${QUIET_TWEAKS_MSG:+\n$QUIET_TWEAKS_MSG}${BT_MSG:+\n$BT_MSG}" -i "$ICON"
log "Notification sent"
