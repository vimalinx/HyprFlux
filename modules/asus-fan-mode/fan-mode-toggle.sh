#!/usr/bin/env bash
# Waybar fan-mode controller for ASUS laptops.

set -euo pipefail

STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/asus-fan-mode"
LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/asus-fan-mode.log"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/asus-fan-mode.lock"
MAX_LOG_LINES=120
NOTIFICATION_TIMEOUT=3000
FAN_RAMP_MIN_RPM="${FAN_RAMP_MIN_RPM:-4000}"
FAN_RAMP_DOWN_DELAY="${FAN_RAMP_DOWN_DELAY:-1.2}"

ASUS_PROFILES=(Quiet Balanced Performance)
RAMP_DOWN_PERCENTS=(85 70 55 40)
FULL_CURVE="0c:100%,40c:100%,50c:100%,60c:100%,70c:100%,80c:100%,90c:100%,100c:100%"

declare -A DEFAULT_CPU_CURVES=(
    [Quiet]="30c:1,58c:21,61c:41,65c:61,70c:77,76c:88,255c:89,255c:89"
    [Balanced]="0c:2,57c:30,62c:43,67c:61,71c:81,73c:102,77c:128,85c:165"
    [Performance]="0c:25,57c:60,60c:74,64c:98,67c:134,71c:168,80c:229,99c:254"
)

declare -A DEFAULT_GPU_CURVES=(
    [Quiet]="39c:1,52c:19,56c:29,60c:47,64c:58,68c:70,255c:71,255c:71"
    [Balanced]="0c:2,54c:31,58c:39,62c:50,67c:67,71c:89,75c:112,83c:142"
    [Performance]="0c:20,47c:30,58c:59,62c:98,66c:150,72c:205,82c:245,99c:254"
)

log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
    if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt "$MAX_LOG_LINES" ]; then
        tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
}

notify() {
    local title="$1"
    local message="$2"
    local icon="${3:-fan}"

    notify-send -t "$NOTIFICATION_TIMEOUT" "$title" "$message" -i "$icon" >/dev/null 2>&1 || true
}

acquire_lock() {
    if ! command -v flock >/dev/null 2>&1; then
        return 0
    fi

    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        notify "风扇模式" "上一次风扇切换还在执行，稍等一下再点。" "dialog-warning"
        log "Fan mode change refused because another change is running"
        exit 1
    fi
}

require_asusctl() {
    if ! command -v asusctl >/dev/null 2>&1; then
        notify "风扇模式" "未找到 asusctl，无法调整风扇" "dialog-error"
        log "ERROR: asusctl not found"
        exit 1
    fi
}

active_profile() {
    asusctl profile get 2>/dev/null | awk -F': ' '/Active profile/ { print $2; exit }'
}

platform_profile() {
    cat /sys/firmware/acpi/platform_profile 2>/dev/null || true
}

stored_mode() {
    local mode="normal"

    if [ -r "$STATE_FILE" ]; then
        mode="$(tr -d '[:space:]' < "$STATE_FILE")"
    fi

    case "$mode" in
        quiet|normal|violent) printf '%s\n' "$mode" ;;
        *) printf 'normal\n' ;;
    esac
}

write_mode() {
    mkdir -p "$(dirname "$STATE_FILE")"
    printf '%s\n' "$1" > "$STATE_FILE"
}

mode_label() {
    case "$1" in
        quiet) printf '安静' ;;
        violent) printf '暴力' ;;
        *) printf '正常' ;;
    esac
}

rpm_summary() {
    sensors 2>/dev/null | awk '
        $1 == "cpu_fan:" { cpu = $2 " " $3 }
        $1 == "gpu_fan:" { gpu = $2 " " $3 }
        END {
            if (cpu == "" && gpu == "") {
                print "unknown"
            } else {
                printf "CPU %s / GPU %s", cpu ? cpu : "unknown", gpu ? gpu : "unknown"
            }
        }
    '
}

max_fan_rpm() {
    sensors 2>/dev/null | awk '
        $1 == "cpu_fan:" || $1 == "gpu_fan:" {
            rpm = $2 + 0
            if (rpm > max) {
                max = rpm
            }
        }
        END {
            print max + 0
        }
    '
}

emit_json() {
    local text="$1"
    local class="$2"
    local tooltip="$3"

    if command -v jq >/dev/null 2>&1; then
        jq -cn --arg text "$text" --arg class "$class" --arg tooltip "$tooltip" \
            '{text:$text,class:$class,tooltip:$tooltip}'
    else
        printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$text" "$class" "$tooltip"
    fi
}

status() {
    local mode profile platform class label rpm tooltip

    mode="$(stored_mode)"
    profile="$(active_profile)"
    platform="$(platform_profile)"
    rpm="$(rpm_summary)"
    class="$mode"
    label="$(mode_label "$mode")"

    if [ "$mode" = "quiet" ] && [ "$profile" != "Quiet" ]; then
        class="locked"
        label="安静锁定"
    fi

    tooltip="$(printf '风扇模式: %s\nASUS: %s\nPlatform: %s\nFan: %s\n左键: 选择模式\n右键: 平滑降速后三档恢复正常曲线\n中键: 三档暴力满速\n安静: 仅 ASUS Quiet 档可用' \
        "$label" "${profile:-unknown}" "${platform:-unknown}" "$rpm")"

    emit_json "󰈐" "$class" "$tooltip"
}

reload_waybar_module() {
    pkill -RTMIN+9 waybar >/dev/null 2>&1 || true
}

run_asusctl() {
    require_asusctl
    log "asusctl fan-curve $*"
    asusctl fan-curve "$@" >> "$LOG_FILE" 2>&1
}

set_fan_curve() {
    local profile="$1"
    local fan="$2"
    local curve="$3"

    run_asusctl --mod-profile "$profile" --fan "$fan" --data "$curve"
    run_asusctl --mod-profile "$profile" --fan "$fan" --enable-fan-curve true
}

constant_curve() {
    local percent="$1"

    printf '0c:%s%%,40c:%s%%,50c:%s%%,60c:%s%%,70c:%s%%,80c:%s%%,90c:%s%%,100c:%s%%' \
        "$percent" "$percent" "$percent" "$percent" "$percent" "$percent" "$percent" "$percent"
}

should_ramp_down() {
    local mode max_rpm

    [ "${FAN_RAMP_DOWN:-1}" = "1" ] || return 1

    mode="$(stored_mode)"
    if [ "$mode" = "violent" ]; then
        return 0
    fi

    max_rpm="$(max_fan_rpm)"
    [ "${max_rpm:-0}" -ge "$FAN_RAMP_MIN_RPM" ]
}

ramp_down_active_profile() {
    local profile="$1"
    local percent curve

    case "$profile" in
        Quiet|Balanced|Performance) ;;
        *) return 0 ;;
    esac

    log "Fan ramp-down start for active profile: $profile"
    for percent in "${RAMP_DOWN_PERCENTS[@]}"; do
        curve="$(constant_curve "$percent")"
        run_asusctl --mod-profile "$profile" --enable-fan-curves true
        set_fan_curve "$profile" cpu "$curve"
        set_fan_curve "$profile" gpu "$curve"
        reload_waybar_module
        sleep "$FAN_RAMP_DOWN_DELAY"
    done
    log "Fan ramp-down complete for active profile: $profile"
}

set_quiet() {
    local profile

    acquire_lock
    profile="$(active_profile)"
    if [ "$profile" != "Quiet" ]; then
        notify "风扇模式" "安静风扇只允许在 ASUS Quiet 电源模式下使用。\n当前: ${profile:-unknown}" "dialog-warning"
        log "Quiet fan mode refused outside ASUS Quiet profile: ${profile:-unknown}"
        exit 2
    fi

    if should_ramp_down; then
        ramp_down_active_profile "$profile"
    fi

    run_asusctl --mod-profile Quiet --enable-fan-curves true
    set_fan_curve Quiet cpu "${DEFAULT_CPU_CURVES[Quiet]}"
    set_fan_curve Quiet gpu "${DEFAULT_GPU_CURVES[Quiet]}"

    write_mode quiet
    reload_waybar_module
    notify "风扇模式" "已切到安静风扇。\n仅适合 Quiet 低功耗档。" "fan"
    log "Fan mode set to quiet"
}

set_normal() {
    local active profile

    acquire_lock
    active="$(active_profile)"
    if should_ramp_down; then
        ramp_down_active_profile "$active"
    fi

    for profile in "${ASUS_PROFILES[@]}"; do
        run_asusctl --mod-profile "$profile" --enable-fan-curves true
        set_fan_curve "$profile" cpu "${DEFAULT_CPU_CURVES[$profile]}"
        set_fan_curve "$profile" gpu "${DEFAULT_GPU_CURVES[$profile]}"
    done

    write_mode normal
    reload_waybar_module
    notify "风扇模式" "已恢复三档正常曲线。\nQuiet / Balanced / Performance" "fan"
    log "Fan mode set to normal for all ASUS profiles"
}

set_violent() {
    local active profile

    acquire_lock
    active="$(active_profile)"
    case "$active" in
        Quiet|Balanced|Performance) ;;
        *)
            notify "风扇模式" "无法识别 ASUS 档位，拒绝设置满速。\n当前: ${active:-unknown}" "dialog-error"
            log "Violent fan mode refused for unknown profile: ${active:-unknown}"
            exit 1
            ;;
    esac

    for profile in "${ASUS_PROFILES[@]}"; do
        run_asusctl --mod-profile "$profile" --enable-fan-curves true
        set_fan_curve "$profile" cpu "$FULL_CURVE"
        set_fan_curve "$profile" gpu "$FULL_CURVE"
    done

    write_mode violent
    reload_waybar_module
    notify "风扇模式" "已切到三档暴力满速。\n后续切电源模式也保持满速。" "fan"
    log "Fan mode set to violent for all ASUS profiles; active profile was: ${active:-unknown}"
}

set_mode() {
    case "${1:-}" in
        quiet) set_quiet ;;
        normal) set_normal ;;
        violent) set_violent ;;
        *)
            notify "风扇模式" "未知风扇模式: ${1:-empty}" "dialog-error"
            exit 2
            ;;
    esac
}

next_mode() {
    local mode profile

    mode="$(stored_mode)"
    profile="$(active_profile)"

    case "$mode" in
        quiet) printf 'normal\n' ;;
        normal) printf 'violent\n' ;;
        violent)
            if [ "$profile" = "Quiet" ]; then
                printf 'quiet\n'
            else
                printf 'normal\n'
            fi
            ;;
        *) printf 'normal\n' ;;
    esac
}

toggle() {
    set_mode "$(next_mode)"
}

menu() {
    local choice

    if command -v rofi >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        choice="$(
            printf '%s\n' \
                '安静  Quiet  仅 Quiet 电源模式' \
                '正常  Normal 恢复默认曲线' \
                '暴力  Full   三档都满速' \
            | rofi -dmenu -i -p '风扇模式' -theme-str 'window {width: 460px;}'
        )"
        case "$choice" in
            安静*) set_quiet ;;
            正常*) set_normal ;;
            暴力*) set_violent ;;
            *) exit 0 ;;
        esac
        return
    fi

    toggle
}

case "${1:-status}" in
    status) status ;;
    menu) menu ;;
    toggle) toggle ;;
    quiet|normal|violent) set_mode "$1" ;;
    *)
        printf 'Usage: %s [status|menu|toggle|quiet|normal|violent]\n' "$0" >&2
        exit 2
        ;;
esac
