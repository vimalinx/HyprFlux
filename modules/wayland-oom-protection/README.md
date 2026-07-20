# Wayland OOM Protection

User systemd drop-in that marks the Hyprland compositor service as a low OOM priority so application scopes can be reclaimed first.

## Files

- `20-oom-protection.conf`: `ManagedOOMPreference=avoid` for `wayland-wm@hyprland.desktop.service`.

## Apply

```bash
mkdir -p ~/.config/systemd/user/wayland-wm@hyprland.desktop.service.d
cp 20-oom-protection.conf ~/.config/systemd/user/wayland-wm@hyprland.desktop.service.d/
systemctl --user daemon-reload
```

Pairs well with `systemd-memory-guard`, which keeps `session.slice` reserved and avoids killing desktop infrastructure under PSI pressure.
