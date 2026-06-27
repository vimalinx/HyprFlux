# Quickshell On Demand

Keep Quickshell out of the steady-state desktop process list, then start it only when the overview or status panel is requested.

This avoids persistent Wayland title/event overhead from a resident Quickshell session while preserving gesture and Waybar access.

## Apply

```bash
mkdir -p ~/.config/quickshell/scripts
cp qs-on-demand.sh ~/.config/quickshell/scripts/
chmod +x ~/.config/quickshell/scripts/qs-on-demand.sh
```

Use `keybinds.snippet`, `gesture.snippet`, and `startup-disabled.snippet` as needed.

## Commands

```bash
qs-on-demand.sh status-open
qs-on-demand.sh status-toggle
qs-on-demand.sh status-close
qs-on-demand.sh overview-toggle
qs-on-demand.sh overview-open
qs-on-demand.sh quit 2200
```

## Dependencies

- `qs` Quickshell CLI
- Hyprland for the example binds/gestures
