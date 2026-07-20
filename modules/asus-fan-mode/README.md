# ASUS Fan Mode

Waybar/helper script that toggles ASUS fan curves through `asusctl` (Quiet / Balanced / Performance presets plus optional aggressive ramp modes).

## Apply

```bash
cp fan-mode-toggle.sh ~/.config/hypr/UserScripts/
chmod +x ~/.config/hypr/UserScripts/fan-mode-toggle.sh
```

Wire a Waybar custom module or keybind to:

```bash
~/.config/hypr/UserScripts/fan-mode-toggle.sh toggle
```

## Notes

ASUS-only. Skip this module on non-ASUS hardware. Fan curve strings are machine-specific; treat the defaults as a starting point for ROG-class laptops.
