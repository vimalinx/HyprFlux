# Low Power Lid Optional

Optional user service that keeps Hyprland running on lid close only while the machine is already in a low-power profile.

This module is intentionally not enabled by default. On the source workstation, startup config leaves this service disabled so systemd-logind can handle ordinary lid-close suspend.

## Behavior

- Detects low-power state from TLP `power-saver`, ASUS `Quiet`, or platform profile `quiet`.
- Starts a `systemd-inhibit --what=handle-lid-switch` blocker only in low-power mode.
- If the lid closes in low-power mode, requests TLP power-saver, ASUS Quiet, low keyboard LEDs, internal panel 60Hz, and DPMS off.
- Stops the inhibitor when leaving low-power mode.

## Apply

```bash
mkdir -p ~/.config/hypr/UserScripts ~/.config/systemd/user
cp low-power-lid.sh ~/.config/hypr/UserScripts/
cp low-power-lid.service ~/.config/systemd/user/
chmod +x ~/.config/hypr/UserScripts/low-power-lid.sh
systemctl --user daemon-reload
```

Enable only if you want this behavior:

```bash
systemctl --user enable --now low-power-lid.service
```

## Verify

```bash
~/.config/hypr/UserScripts/low-power-lid.sh --status
systemctl --user status low-power-lid.service
```

## Startup Snippet

The source workstation keeps this disabled in Hyprland startup:

```text
# exec-once = systemctl --user start low-power-lid.service
```
