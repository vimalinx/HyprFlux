# Safety Notes

HyprFlux is a public collection, so it deliberately avoids publishing complete private dotfiles.

## Do Not Copy Raw

Avoid copying these files directly into public repos:

- Shell startup files such as `.bashrc`, `.zshrc`, and profile files.
- Full Codex, Claude, OMP, provider, or API-client configuration.
- Browser, cookie, session, SSH, cloud, or deployment state.
- Full Waybar/Hyprland trees if they include private scripts or host-specific paths.

## Apply One Module At A Time

Several modules affect live desktop behavior:

- PipeWire audio routing can change the default microphone.
- NVIDIA modprobe and TLP drop-ins are system-level files and can affect boot, GPU offload, CUDA, runtime power, and display behavior.
- ASUS/TLP power scripts can change refresh rate, brightness, radios, Bluetooth, blur, and battery charge thresholds.
- SDDM greeter pinning is display-manager config; test it only when you can recover from a TTY.
- Waydroid helpers may require ADB Keyboard inside Waydroid and should not be mixed with host firewall/VPN routing changes unless reviewed.
- `wl-copy` wrappers shadow the system binary when `~/.local/bin` comes first in `PATH`; smoke test stdin copy, argument copy, and `--clear`.
- Startup restore scripts can reopen terminals and increase login-time load.
- Waybar scripts may scan process tables or Hyprland clients.
- Clipboard services should not be duplicated with old `exec-once wl-paste` lines.

Prefer a backup, then apply and test a single module before moving on.

## Checks

Run:

```bash
./scripts/check.sh
```

The check script validates shell syntax and scans for common credential-shaped patterns.
