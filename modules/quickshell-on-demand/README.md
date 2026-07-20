# Quickshell On Demand

Starts `qs` only when an IPC surface is needed. Current live script supports Action Desk, status panel, terminals tab aliases, and overview.

## Files

- `qs-on-demand.sh`
- `keybinds.snippet`
- `waybar-click.snippet`
- `gesture.snippet`
- `startup-disabled.snippet`

## Apply

```bash
mkdir -p ~/.config/quickshell/scripts
cp qs-on-demand.sh ~/.config/quickshell/scripts/
chmod +x ~/.config/quickshell/scripts/qs-on-demand.sh
```

Merge keybind snippets. Keep Quickshell out of unconditional `exec-once` if you want on-demand startup.
