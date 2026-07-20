# Generic Power Stack

Non-ASUS power profile stack for machines without `asusctl` / `asusd`.

Uses `power-profiles-daemon` when available, otherwise TLP via `tlpctl`. Battery charge limits use sysfs `charge_control_end_threshold` with optional `pkexec` write access.

## When To Use

Install this profile branch when HyprFlux detects a non-ASUS vendor, or when you explicitly choose the generic power stack.

Do **not** install `asus-tlp-power-stack` or `asus-fan-mode` on the same machine unless you know you have ASUS firmware controls.

## Files

- `toggle-power-profile.sh`: cycles Power Saver → Balanced → Performance and nudges Hyprland refresh.
- `battery-toggle.sh`: cycles 80 → 60 → 100 → 80 on supported batteries.
- `waybar-power-mode.sh`: Waybar indicator for the active backend/profile.
- `keybinds.snippet` / `waybar-module.jsonc`: integration snippets.

## Apply

```bash
mkdir -p ~/.config/hypr/UserScripts ~/.config/hypr/scripts
cp toggle-power-profile.sh battery-toggle.sh ~/.config/hypr/UserScripts/
cp waybar-power-mode.sh ~/.config/hypr/scripts/
# Reuse the shared battery limit display from waybar-power-status:
cp ../waybar-power-status/waybar_battery_limit.sh ~/.config/hypr/scripts/
chmod +x ~/.config/hypr/UserScripts/*.sh ~/.config/hypr/scripts/*.sh
```

Merge the keybind and Waybar snippets, then restart Waybar.

## Verify

```bash
powerprofilesctl get || tlpctl get
cat /sys/class/power_supply/BAT*/charge_control_end_threshold
```
