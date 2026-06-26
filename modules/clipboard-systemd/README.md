# Clipboard Systemd Units

Runs text and image clipboard history watchers as systemd user services. This avoids duplicate `wl-paste --watch cliphist store` entries in Hyprland startup files.

## Dependencies

- `wl-paste`
- `cliphist`
- systemd user session

## Apply

```bash
mkdir -p ~/.config/systemd/user
cp cliphist.service cliphist-image.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now cliphist.service cliphist-image.service
```

Remove or comment out old Hyprland startup entries like:

```text
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
```

Use the included `hypr-startup-snippet.conf` as the safe startup comment block.
