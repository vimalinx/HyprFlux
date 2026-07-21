# Waybar Symlink Fix

Repairs JaKooLit waybar symlinks that still point at the template user home after dots install.

## What it does

- Recreates `~/.config/waybar/config` → `$HOME/.config/waybar/configs/[TOP] Default Laptop` when present (else Default, Simple, or first `[TOP]*` layout).
- Recreates `~/.config/waybar/style.css` → `[Wallust] Colored.css` when present (else Translucent / other JaKooLit stock styles).
- Rewrites stale template-user home paths inside waybar/hypr helper scripts when found.

Applied automatically by HyprFlux on every machine after JaKooLit dots are installed.
