# Waybar Workspace Scroll

Matches Waybar workspace scroll direction to the Hyprland `SUPER + wheel` direction.

## Apply

Use the snippet for the active workspace module in your Waybar config. This setup uses `hyprland/workspaces#numbers`.

Reload Waybar after editing:

```bash
pkill waybar
waybar &
```

## Expected State

```text
scroll up   -> hyprctl dispatch workspace e-1
scroll down -> hyprctl dispatch workspace e+1
```
