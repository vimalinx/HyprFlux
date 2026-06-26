# ASUS TLP Power Stack

ASUS laptop power stack that keeps `asusd`/`asusctl`, TLP/TLP-PD, Waybar, and Hyprland refresh-rate behavior aligned.

This module is based on an ASUS ROG Zephyrus G16 style setup. Treat it as a template: profile names are reusable, but CPU limits, monitor mode, and battery device names should be checked on your own machine.

## Source Pattern

- `tlp`, `tlp-pd`, `asusd`, and `supergfxd` are active.
- `powerprofilesctl` is not required.
- Runtime/default target is balanced.
- Quiet mode maps to lower refresh, lower brightness, stopped CAVA, optional Wi-Fi powersave, and idle Bluetooth off.
- Startup auto GPU/power watchers are kept disabled because they previously fought the manual F5 stack and caused login/session churn.

## Files

- `tlp-asus-g16-power.conf.template`: TLP drop-in profile mapping.
- `asusd-power.ron.snippet`: relevant `/etc/asusd/asusd.ron` settings.
- `asus-profile.conf`: user-tunable profile behavior.
- `toggle-asus-profile.sh`: cycles Quiet -> Balanced -> Performance with TLP sync.
- `keybinds.snippet`: Hyprland binds for F5/Fn+F5 and battery threshold.
- `set-balanced-boot.sh`: copy-safe helper shape for root-owned TLP config.
- `startup-disabled-watchers.snippet`: documents watchers kept disabled by default.

## Apply

Copy user scripts:

```bash
mkdir -p ~/.config/hypr/UserScripts
cp asus-profile.conf toggle-asus-profile.sh ~/.config/hypr/UserScripts/
chmod +x ~/.config/hypr/UserScripts/toggle-asus-profile.sh
```

Merge `keybinds.snippet` into your Hyprland user keybind file.

For TLP, inspect then install:

```bash
sudo install -m 0644 tlp-asus-g16-power.conf.template /etc/tlp.d/01-asus-g16-power.conf
sudo systemctl restart tlp
```

If editing root-owned TLP config by hand is error-prone, adapt and run `set-balanced-boot.sh`.

## Verify

```bash
tlpctl get
cat /sys/firmware/acpi/platform_profile
asusctl profile get
systemctl is-active tlp tlp-pd asusd supergfxd
```

For power-drain questions, also check:

```bash
upower -i /org/freedesktop/UPower/devices/battery_BAT1
hyprctl monitors
supergfxctl -S
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status
```
