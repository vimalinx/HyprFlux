#!/usr/bin/env bash

set -euo pipefail

PRIMARY_OUTPUT="${HYPR_PRIMARY_OUTPUT:-eDP-1}"
SECONDARY_OUTPUT="${HYPR_SECONDARY_OUTPUT:-DP-1}"
SECONDARY_DESCRIPTION_PREFIX="${HYPR_SECONDARY_DESCRIPTION_PREFIX:-GWD ARZOPA}"
SLOT_COUNT=10

usage() {
    cat >&2 <<'EOF'
Usage:
  dual-monitor-workspaces.sh switch <1-10> [active|cursor]
  dual-monitor-workspaces.sh move <1-10> [active|cursor]
  dual-monitor-workspaces.sh move-silent <1-10> [active|cursor]
  dual-monitor-workspaces.sh cycle <next|prev> [active|cursor]
  dual-monitor-workspaces.sh move-cycle <next|prev> [active|cursor]
  dual-monitor-workspaces.sh move-cycle-silent <next|prev> [active|cursor]
EOF
    exit 2
}

active_monitor() {
    hyprctl activeworkspace -j | jq -er '.monitor'
}

cursor_monitor() {
    local cursor x y monitor

    cursor="$(hyprctl cursorpos -j)"
    x="$(jq -r '.x' <<<"$cursor")"
    y="$(jq -r '.y' <<<"$cursor")"

    if monitor="$(hyprctl monitors -j | jq -er \
        --argjson x "$x" --argjson y "$y" \
        'first(.[] | select(
            $x >= .x and $x < (.x + (.width / .scale)) and
            $y >= .y and $y < (.y + (.height / .scale))
        )) | .name')"; then
        printf '%s\n' "$monitor"
    else
        active_monitor
    fi
}

monitor_for_context() {
    case "${1:-active}" in
        active) active_monitor ;;
        cursor) cursor_monitor ;;
        *) usage ;;
    esac
}

monitor_is_secondary() {
    local monitor="$1" description

    if [[ "$monitor" == "$SECONDARY_OUTPUT" ]]; then
        return 0
    fi

    description="$(hyprctl monitors -j | jq -r --arg monitor "$monitor" \
        '.[] | select(.name == $monitor) | .description' | head -n 1)"
    [[ "$description" == "$SECONDARY_DESCRIPTION_PREFIX"* ]]
}

base_for_monitor() {
    if monitor_is_secondary "$1"; then
        printf '10\n'
    else
        printf '0\n'
    fi
}

validate_slot() {
    local slot="$1"
    if [[ ! "$slot" =~ ^[0-9]+$ ]] || ((slot < 1 || slot > SLOT_COUNT)); then
        usage
    fi
}

workspace_for_slot() {
    local monitor="$1" slot="$2" base
    validate_slot "$slot"
    base="$(base_for_monitor "$monitor")"
    printf '%s\n' "$((base + slot))"
}

current_workspace_for_monitor() {
    local monitor="$1"
    hyprctl monitors -j | jq -er --arg monitor "$monitor" \
        '.[] | select(.name == $monitor) | .activeWorkspace.id'
}

cycled_workspace() {
    local monitor="$1" direction="$2" base low high current target

    base="$(base_for_monitor "$monitor")"
    low="$((base + 1))"
    high="$((base + SLOT_COUNT))"
    current="$(current_workspace_for_monitor "$monitor")"

    case "$direction" in
        next)
            if [[ "$current" =~ ^[0-9]+$ ]] && ((current >= low && current < high)); then
                target="$((current + 1))"
            else
                target="$low"
            fi
            ;;
        prev)
            if [[ "$current" =~ ^[0-9]+$ ]] && ((current > low && current <= high)); then
                target="$((current - 1))"
            else
                target="$high"
            fi
            ;;
        *) usage ;;
    esac

    printf '%s\n' "$target"
}

action="${1:-}"

case "$action" in
    switch|move|move-silent)
        slot="${2:-}"
        context="${3:-active}"
        monitor="$(monitor_for_context "$context")"
        target="$(workspace_for_slot "$monitor" "$slot")"

        case "$action" in
            switch) hyprctl -q dispatch workspace "$target" ;;
            move) hyprctl -q dispatch movetoworkspace "$target" ;;
            move-silent) hyprctl -q dispatch movetoworkspacesilent "$target" ;;
        esac
        ;;
    cycle|move-cycle|move-cycle-silent)
        direction="${2:-}"
        context="${3:-active}"
        monitor="$(monitor_for_context "$context")"
        target="$(cycled_workspace "$monitor" "$direction")"

        case "$action" in
            cycle) hyprctl -q dispatch workspace "$target" ;;
            move-cycle) hyprctl -q dispatch movetoworkspace "$target" ;;
            move-cycle-silent) hyprctl -q dispatch movetoworkspacesilent "$target" ;;
        esac
        ;;
    *) usage ;;
esac
