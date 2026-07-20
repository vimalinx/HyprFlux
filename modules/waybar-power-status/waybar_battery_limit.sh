#!/bin/bash
# Waybar battery charge-limit display.

ICON_80="󰔸"
ICON_60="󰂃"
ICON_100="󱟢"

BAT=$(ls /sys/class/power_supply/ | grep BAT | head -n 1)
CHARGE_FILE="/sys/class/power_supply/$BAT/charge_control_end_threshold"
CAPACITY_FILE="/sys/class/power_supply/$BAT/capacity"

if [ -f "$CHARGE_FILE" ]; then
    LIMIT=$(cat "$CHARGE_FILE")
    CAPACITY=$(cat "$CAPACITY_FILE")
    TEXT="$CAPACITY/$LIMIT%"

    if [ "$LIMIT" -eq 80 ]; then
        echo "{\"text\": \"$TEXT\", \"tooltip\": \"Battery protection: 80% (healthy)\", \"class\": \"good\", \"alt\": \"80\"}"
    elif [ "$LIMIT" -eq 60 ]; then
        echo "{\"text\": \"$TEXT\", \"tooltip\": \"Battery protection: 60% (longevity)\", \"class\": \"warning\", \"alt\": \"60\"}"
    elif [ "$LIMIT" -eq 100 ]; then
        echo "{\"text\": \"$TEXT\", \"tooltip\": \"Battery protection: 100% (full)\", \"class\": \"critical\", \"alt\": \"100\"}"
    else
        echo "{\"text\": \"$TEXT\", \"tooltip\": \"Current limit: $LIMIT%\", \"class\": \"info\"}"
    fi
else
    echo "{\"text\": \"Err\", \"tooltip\": \"Unable to read battery limit\"}"
fi
