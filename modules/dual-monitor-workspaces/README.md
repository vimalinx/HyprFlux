# Dual Monitor Workspaces

Independent workspace banks for a laptop panel and a side display. Hyprland workspace IDs stay global (1–10 and 11–20) while the helper presents local slots 1–10 per monitor.

## Files

- `dual-monitor-workspaces.sh`: switch / move / cycle helpers with active or cursor monitor context.
- `workspaces.conf.template`: example persistent workspace bindings. Edit monitor names before use.

## Apply

```bash
cp dual-monitor-workspaces.sh ~/.config/hypr/scripts/
chmod +x ~/.config/hypr/scripts/dual-monitor-workspaces.sh
# Adapt monitor names, then:
cp workspaces.conf.template ~/.config/hypr/UserConfigs/DualMonitorWorkspaces.conf
```

Source the conf from your Hyprland user config and bind keys to:

```bash
~/.config/hypr/scripts/dual-monitor-workspaces.sh switch <1-10>
```

Optional environment overrides:

- `HYPR_PRIMARY_OUTPUT` (default `eDP-1`)
- `HYPR_SECONDARY_OUTPUT` (default `DP-1`)
- `HYPR_SECONDARY_DESCRIPTION_PREFIX` (default `GWD ARZOPA`)
