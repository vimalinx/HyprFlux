# Waybar CAVA Low Power

This module wraps CAVA for Waybar so it does not keep an audio visualizer running all the time.

## Behavior

- Prints a static bar while no audio is playing.
- Starts `cava` only when `playerctl -a status` reports `Playing`.
- Stops `cava` again when playback stops or a quiet power profile is active.
- Cleans up child CAVA processes when Waybar exits.

## Dependencies

- `bash`
- `cava`
- `playerctl`
- Optional: `tlpctl` if `WAYBAR_CAVA_CHECK_TLP=1`

## Apply

Copy `WaybarCava.sh` to your Hyprland script directory and reference it from a Waybar custom module:

```jsonc
"custom/cava_mviz": {
  "exec": "$HOME/.config/hypr/scripts/WaybarCava.sh",
  "format": "{}",
  "restart-interval": 2
}
```

## Environment Knobs

- `WAYBAR_CAVA_IDLE_POLL`: idle polling interval in seconds, default `5`.
- `WAYBAR_CAVA_STATIC`: static bar text, default is an eight-block bar.
- `WAYBAR_CAVA_DISABLE_ON_QUIET`: disable live CAVA in quiet power profile, default `1`.
- `WAYBAR_CAVA_CHECK_TLP`: check `tlpctl get` for `power-saver`, default `0`.
- `WAYBAR_CAVA_STATUS_POLL`: active playback check interval, default `2`.
