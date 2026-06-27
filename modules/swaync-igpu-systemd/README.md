# SwayNC iGPU Systemd

Run SwayNC through its systemd user unit and force it onto the iGPU/Mesa stack.

## Why

Starting SwayNC from both Hyprland `exec-once` and the systemd user unit can create startup races. On hybrid NVIDIA laptops, notification daemons can also accidentally touch the dGPU. This module keeps SwayNC owned by systemd and applies conservative iGPU environment variables.

## Apply

```bash
mkdir -p ~/.config/systemd/user/swaync.service.d
cp 10-force-igpu.conf ~/.config/systemd/user/swaync.service.d/
systemctl --user daemon-reload
systemctl --user enable --now swaync.service
```

In Hyprland startup, keep direct SwayNC launch disabled:

```text
# exec-once = swaync
```

## Verify

```bash
systemctl --user is-enabled swaync.service
systemctl --user is-active swaync.service
busctl --user list | rg Notifications
```
