# Hyprland Terminal Bind Fix

JaKooLit `hyprland.conf` sources `configs/Keybinds.conf` before `UserConfigs/01-UserDefaults.conf`, so `$term` is undefined when early keybinds are parsed. Super+Return can launch the literal string `$term`.

## What it does

- Writes `UserConfigs/HyprFluxTerm.conf` with absolute-path `$term` and `$terminal` (kitty, else foot, else alacritty/wezterm).
- Inserts an early `source = $HOME/.config/hypr/UserConfigs/HyprFluxTerm.conf` line **before** `Keybinds.conf` in `hyprland.conf`.
- Writes `UserConfigs/HyprFluxKeybinds.conf` with Super+Return using the absolute terminal path and ensures `UserKeybinds.conf` sources it.
- Syncs `01-UserDefaults.conf` `$term` when that file already defines it.

Applied automatically by HyprFlux on every machine after JaKooLit dots are installed.
