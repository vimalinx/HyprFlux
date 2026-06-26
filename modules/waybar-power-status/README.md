# Waybar Power Status

Waybar modules for ASUS/TLP power mode and battery charge limit.

## What It Shows

- `custom/power_mode`: platform profile, TLP profile, and expected mapping.
- `custom/battery_limit`: current battery percentage plus charge limit.

## Dependencies

- Waybar
- `tlpctl` for TLP profile readback
- `/sys/firmware/acpi/platform_profile`
- `/sys/class/power_supply/BAT*/charge_control_end_threshold`
- `pkexec` for changing the battery threshold
- Optional ASUS module from `asus-tlp-power-stack`

## Apply

Copy scripts:

```bash
mkdir -p ~/.config/hypr/scripts ~/.config/hypr/UserScripts
cp waybar-power-mode.sh waybar_battery_limit.sh ~/.config/hypr/scripts/
cp battery-toggle.sh ~/.config/hypr/UserScripts/
chmod +x ~/.config/hypr/scripts/waybar-power-mode.sh ~/.config/hypr/scripts/waybar_battery_limit.sh ~/.config/hypr/UserScripts/battery-toggle.sh
```

Merge `waybar-module.jsonc` into your Waybar user modules and add both modules to a bar or drawer.

## Notes

The battery toggle cycles `80 -> 60 -> 100 -> 80` and writes both sysfs and `/etc/battery_charge_limit` through `pkexec`. Adjust the persistent file if your distro uses a different mechanism.
