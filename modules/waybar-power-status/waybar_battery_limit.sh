#!/bin/bash
# Waybar 电池限制显示脚本

# 默认图标和颜色
ICON_80="󰔸" # 盾牌 (保护)
ICON_60="󰂃" # 插头 (长寿命)
ICON_100="󱟢" # 闪电 (满血)

# 获取 BAT1 或 BAT0
BAT=$(ls /sys/class/power_supply/ | grep BAT | head -n 1)
CHARGE_FILE="/sys/class/power_supply/$BAT/charge_control_end_threshold"
CAPACITY_FILE="/sys/class/power_supply/$BAT/capacity"

if [ -f "$CHARGE_FILE" ]; then
    LIMIT=$(cat "$CHARGE_FILE")
    CAPACITY=$(cat "$CAPACITY_FILE")
    
    # 紧凑模式: 去掉空格，例如 80/80%
    TEXT="$CAPACITY/$LIMIT%"
    
    if [ "$LIMIT" -eq 80 ]; then
        echo "{\"text\": \"$TEXT\", \"tooltip\": \"电池保护: 80% (健康)\", \"class\": \"good\", \"alt\": \"80\"}"
    elif [ "$LIMIT" -eq 60 ]; then
        echo "{\"text\": \"$TEXT\", \"tooltip\": \"电池保护: 60% (长寿命)\", \"class\": \"warning\", \"alt\": \"60\"}"
    elif [ "$LIMIT" -eq 100 ]; then
        echo "{\"text\": \"$TEXT\", \"tooltip\": \"电池保护: 100% (充满)\", \"class\": \"critical\", \"alt\": \"100\"}"
    else
        echo "{\"text\": \"$TEXT\", \"tooltip\": \"当前限制: $LIMIT%\", \"class\": \"info\"}"
    fi
else
    echo "{\"text\": \"Err\", \"tooltip\": \"无法读取电池设置\"}"
fi
