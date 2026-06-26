# Hypridle Power Policy

Battery-aware Hypridle policy for lock, DPMS, and suspend.

## Behavior

- Warn after 9 minutes idle.
- Lock after 10 minutes idle.
- Turn off displays shortly after lock.
- Suspend after 20 minutes idle only if UPower reports the display device is discharging.

## Apply

Merge `hypridle.conf.snippet` into your `~/.config/hypr/hypridle.conf`.

Ensure Hyprland starts Hypridle:

```text
exec-once = hypridle
```

## Why Battery-Gated Suspend

The source workstation is often used on AC for long-running agents and local services. The suspend rule therefore checks the real power state instead of suspending unconditionally.
