# Bar Services Startup

Moves Waybar and SwayNC startup from JaKooLit `exec-once` lines to systemd user units.

## What it does

- Backs up then comments out `exec-once = waybar` and `exec-once = swaync` in Hyprland startup configs.
- Enables `waybar.service` and `swaync.service` when those units exist (JaKooLit ships them).
- Complements `swaync-igpu-systemd`, which only adds the iGPU drop-in.

Re-run HyprFlux install or log out/in after applying so duplicate startup races stop.
