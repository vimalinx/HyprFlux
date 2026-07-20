# VibeMouse Waybar

Waybar status module for [VibeMouse](https://github.com/vimalinx/VibeMouse) recording / transcription state, plus an optional inotify watcher service that refreshes Waybar when the status file changes.

## Files

- `waybar-vibemouse-status.sh`
- `waybar-vibemouse-watch.sh`
- `vibemouse-waybar-watch.service`
- `waybar-module.jsonc`

## Apply

Install VibeMouse first, then:

```bash
cp waybar-vibemouse-status.sh waybar-vibemouse-watch.sh ~/.config/hypr/scripts/
chmod +x ~/.config/hypr/scripts/waybar-vibemouse-*.sh
cp vibemouse-waybar-watch.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now vibemouse-waybar-watch.service
```

Merge `waybar-module.jsonc` into your Waybar config.
