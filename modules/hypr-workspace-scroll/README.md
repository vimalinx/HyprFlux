# Hyprland Workspace Scroll

Reverses `SUPER + mouse wheel` workspace switching so the wheel direction matches this setup's preferred spatial model.

## Apply

Copy the two `mouse_*` lines from `Keybinds.conf.snippet` into your Hyprland keybind config, replacing the existing workspace scroll binds.

Then reload Hyprland:

```bash
hyprctl reload
```

## Expected State

```text
SUPER + wheel down -> previous existing workspace
SUPER + wheel up   -> next existing workspace
```
