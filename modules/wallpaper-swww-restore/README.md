# Wallpaper SWWW Restore

Robust Hyprland wallpaper restore for `swww`.

## Behavior

- Starts `swww-daemon` if it is not already running.
- Applies the current wallpaper per monitor when monitor names are available.
- Falls back to global `swww img` if monitor detection fails.
- Keeps the Rofi and Hyprland "current wallpaper" pointers in sync.
- Reapplies the wallpaper when the monitor set changes.

## Apply

```bash
mkdir -p ~/.config/hypr/scripts
cp SetWallpaper.sh MonitorWallpaperSync.sh ~/.config/hypr/scripts/
chmod +x ~/.config/hypr/scripts/SetWallpaper.sh ~/.config/hypr/scripts/MonitorWallpaperSync.sh
```

Add to Hyprland startup:

```text
exec-once = $scriptsDir/SetWallpaper.sh "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
exec-once = $scriptsDir/MonitorWallpaperSync.sh
```

## Dependencies

- `swww`
- `hyprctl`
- `jq`
