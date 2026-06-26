#!/bin/bash
set -euo pipefail

tlp_profile_cache=""
tlp_profile_checked=-9999
parent_pid="$PPID"

parent_alive() {
    [ "$parent_pid" -gt 1 ] && kill -0 "$parent_pid" 2>/dev/null
}

read_tlp_profile() {
    local now="$SECONDS"
    local poll_interval="${WAYBAR_CAVA_TLP_POLL:-60}"

    if (( now - tlp_profile_checked < poll_interval )); then
        printf '%s\n' "$tlp_profile_cache"
        return 0
    fi

    tlp_profile_checked="$now"
    tlp_profile_cache=""

    command -v tlpctl >/dev/null 2>&1 || return 0
    if command -v timeout >/dev/null 2>&1; then
        tlp_profile_cache="$(timeout 0.5s tlpctl get 2>/dev/null || true)"
    else
        tlp_profile_cache="$(tlpctl get 2>/dev/null || true)"
    fi

    printf '%s\n' "$tlp_profile_cache"
}

quiet_profile_active() {
    if [ -r /sys/firmware/acpi/platform_profile ] && [ "$(cat /sys/firmware/acpi/platform_profile)" = "quiet" ]; then
        return 0
    fi

    [ "${WAYBAR_CAVA_CHECK_TLP:-0}" = "1" ] && [ "$(read_tlp_profile)" = "power-saver" ]
}

audio_playing() {
    command -v playerctl >/dev/null 2>&1 || return 1
    playerctl -a status 2>/dev/null | grep -qx "Playing"
}

render_line() {
    local line="${1//;/}"
    line="${line//0/▁}"
    line="${line//1/▂}"
    line="${line//2/▃}"
    line="${line//3/▄}"
    line="${line//4/▅}"
    line="${line//5/▆}"
    line="${line//6/▇}"
    line="${line//7/█}"
    printf '%s\n' "$line"
}

wait_until_visualizer_needed() {
    local idle_poll="${WAYBAR_CAVA_IDLE_POLL:-5}"
    local static_bar="${WAYBAR_CAVA_STATIC:-▁▁▁▁▁▁▁▁}"

    while true; do
        parent_alive || exit 0

        if [ "${WAYBAR_CAVA_DISABLE_ON_QUIET:-1}" = "1" ] && quiet_profile_active; then
            printf '%s\n' "$static_bar"
        elif audio_playing; then
            return 0
        else
            printf '%s\n' "$static_bar"
        fi

        sleep "$idle_poll"
    done
}

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
config_file="$runtime_dir/waybar-cava-$$.conf"
cava_pid=""

stop_cava() {
    if [ -n "${cava_pid:-}" ] && kill -0 "$cava_pid" 2>/dev/null; then
        kill "$cava_pid" 2>/dev/null || true
        wait "$cava_pid" 2>/dev/null || true
    fi
    while IFS= read -r pid; do
        [ -n "$pid" ] && [ "$pid" != "$$" ] && kill "$pid" 2>/dev/null || true
    done < <(ps -eo pid=,comm=,args= | awk -v conf="$config_file" '$2 == "cava" && index($0, "cava -p " conf) { print $1 }')
    cava_pid=""
}

cleanup() {
    stop_cava
    rm -f "$config_file"
}

trap cleanup EXIT
trap 'cleanup; exit 0' HUP INT TERM

cat >"$config_file" <<EOF
[general]
framerate = 12
bars = 8

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

while true; do
    wait_until_visualizer_needed

    stop_cava
    coproc CAVA_PROC { exec cava -p "$config_file"; }
    cava_pid="$CAVA_PROC_PID"
    cava_fd="${CAVA_PROC[0]}"
    next_check=$((SECONDS + ${WAYBAR_CAVA_STATUS_POLL:-2}))

    while IFS= read -r line <&"$cava_fd"; do
        parent_alive || break
        render_line "$line"

        if [ "$SECONDS" -ge "$next_check" ]; then
            if ! audio_playing || { [ "${WAYBAR_CAVA_DISABLE_ON_QUIET:-1}" = "1" ] && quiet_profile_active; }; then
                break
            fi
            next_check=$((SECONDS + ${WAYBAR_CAVA_STATUS_POLL:-2}))
        fi
    done

    exec {cava_fd}<&- 2>/dev/null || true
    stop_cava
done
