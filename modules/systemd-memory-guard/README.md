# Systemd Memory Guard

User systemd slice drop-ins for a Hyprland / UWSM desktop:

- `app.slice`: no fixed RAM quota and no PSI kill; keep only a near-exhaustion swap emergency brake.
- `session.slice`: reserve a small working set for desktop infrastructure and omit it from oomd selection.

## Apply

```bash
mkdir -p ~/.config/systemd/user/app.slice.d ~/.config/systemd/user/session.slice.d
cp app.slice-memory-guard.conf ~/.config/systemd/user/app.slice.d/10-memory-guard.conf
cp session.slice-memory-guard.conf ~/.config/systemd/user/session.slice.d/10-memory-guard.conf
systemctl --user daemon-reload
```

Pair with `wayland-oom-protection` so the compositor is an even lower OOM priority than ordinary apps.
