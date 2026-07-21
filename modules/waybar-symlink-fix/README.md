# Waybar Symlink Fix

Repairs JaKooLit waybar symlinks that still point at the template user home after dots install.

## What it does

- Recreates `~/.config/waybar/config` → `$HOME/.config/waybar/configs/[TOP] Simple` (or the first available `[TOP]*` layout).
- Recreates `~/.config/waybar/style.css` → a Colored/Translucent style when present.
- Rewrites stale template-user home paths inside waybar/hypr helper scripts when found.

Applied automatically by HyprFlux on every machine after JaKooLit dots are installed.
