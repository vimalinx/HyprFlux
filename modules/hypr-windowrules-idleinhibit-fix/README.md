# Hypr WindowRules Idle-Inhibit Fix

Fixes JaKooLit `WindowRules.conf` entries that crash Hyprland 0.56:

```text
windowrule = idle_inhibit fullscreen, match:class ^(*)$
```

## What it does

- Deletes lines containing the invalid `^(*)$` regex from `configs/WindowRules.conf` (with backup).
- Adds a valid Hyprland 0.56 block rule via `UserConfigs/HyprFluxWindowRules.conf`.
- Ensures `UserConfigs/WindowRules.conf` sources the override file.
