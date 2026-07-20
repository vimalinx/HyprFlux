# HyprFlux Overview

HyprFlux is a full Arch + Hyprland desktop bootstrap extracted from a real workstation, plus a module overlay for day-to-day tweaks.

## Layers

1. **Packages** — official Arch packages plus a small AUR set (`bootstrap/packages-*.txt`).
2. **Base dots** — [JaKooLit/Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots) copied into `~/.config`.
3. **HyprFlux modules** — profile-aware overlays (ASUS vs generic power, mic stacks, Quickshell on-demand, etc.).
4. **Session wiring** — `HyprFluxStartup.conf` sourced from JaKooLit `Startup_Apps.conf`.

## Design Rules

- Full bootstrap for bare Arch; `./install.sh` remains available as a modules-only overlay.
- Public-safe: no private shell startups, provider keys, cookies, or complete private dotfile dumps.
- Confirmation prompts read from `/dev/tty` so `curl | bash` does not auto-abort.
- ASUS helpers never auto-start on non-ASUS machines.
