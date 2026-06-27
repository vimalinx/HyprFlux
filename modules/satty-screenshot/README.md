# Satty Screenshot

Annotated screenshot helper for Hyprland using `hyprshot` and `satty`.

## Behavior

- Captures region, active/window, or output via `hyprshot`.
- Pipes the image into `satty`.
- Saves into `~/Pictures/Screenshots`.
- Copies through `wl-copy`.
- Exits early after save/copy.

## Apply

```bash
mkdir -p ~/.config/hypr/UserScripts
cp satty-shot.sh ~/.config/hypr/UserScripts/
chmod +x ~/.config/hypr/UserScripts/satty-shot.sh
```

Merge `keybinds.snippet` into your Hyprland keybinds.

## Dependencies

- `hyprshot`
- `satty`
- `wl-copy`
