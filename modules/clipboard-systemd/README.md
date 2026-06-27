# Clipboard Systemd Units

Runs text and image clipboard history watchers as systemd user services. This avoids duplicate `wl-paste --watch cliphist store` entries in Hyprland startup files.

It also includes an optional `wl-copy` wrapper that avoids `xdg-mime`/`xprop` hangs under Hyprland/XWayland while preserving both stdin and positional text copy behavior.

## Dependencies

- `wl-paste`
- `cliphist`
- `file` for the optional `wl-copy` wrapper
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

## Optional `wl-copy` Wrapper

Install only if your desktop has `wl-copy` hangs or XWayland client exhaustion related to `xdg-mime`/`xprop`:

```bash
mkdir -p ~/.local/bin
cp wl-copy-wrapper ~/.local/bin/wl-copy
chmod +x ~/.local/bin/wl-copy
```

Smoke test both invocation styles:

```bash
printf test | wl-copy
wl-paste
wl-copy "argument text"
wl-paste
wl-copy --clear
```
