# HyprFlux

<div align="center">

**Full Arch Linux + Hyprland desktop bootstrap**

[Install](#install) · [What you get](#what-you-get) · [Profiles](#profiles) · [Safety](docs/safety.md)

</div>

---

HyprFlux turns a **minimal Arch install** into a usable Hyprland desktop:

1. Installs the package stack (pacman + AUR)
2. Installs [JaKooLit Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots) as the public base rice
3. Overlays HyprFlux modules (ASUS or generic power, mic, Quickshell helpers, etc.)
4. Wires session startup and enables SDDM / PipeWire where possible

It is **not** a dump of one private home directory. It is a reproducible public stack that aims to feel like a finished workstation after reboot.

## Install

Landing page: [arch.vimalinx.com](https://arch.vimalinx.com)

```bash
bash <(curl -fsSL https://arch.vimalinx.com/install)
```

Compatible pipe form:

```bash
curl -fsSL https://arch.vimalinx.com/install | bash
```

Non-interactive / force generic power stack:

```bash
HF_YES=1 bash <(curl -fsSL https://arch.vimalinx.com/install)
HF_PROFILE=generic HF_YES=1 bash <(curl -fsSL https://arch.vimalinx.com/install)
```

Or clone locally:

```bash
git clone https://github.com/vimalinx/HyprFlux.git
cd HyprFlux
./bootstrap/full.sh
```

Module-only overlay (existing Hyprland desktop):

```bash
./install.sh
```

## What you get

After a successful full bootstrap on bare Arch:

- Hyprland + Waybar + SDDM + PipeWire desktop base (via packages + JaKooLit dots)
- HyprFlux profile modules applied on top
- `HyprFluxStartup.conf` sourced from `Startup_Apps.conf`
- ASUS machines get asusctl/TLP helpers; others get the generic power stack

Then: **reboot → log in through SDDM → Hyprland**.

## Profiles

| Profile | When | Power stack |
|---|---|---|
| `asus` | ASUSTeK / ROG / TUF / Zephyrus, or live `asusd` | `asus-tlp-power-stack`, `asus-fan-mode` |
| `generic` | everything else | `generic-power-stack` |

## Checks

```bash
./scripts/check.sh
```

## Design

- Full bootstrap for bare Arch; module overlay for existing desktops
- Public-safe: no private shell rc dumps, API keys, or agent secrets
- Confirmation prompts read from `/dev/tty` so `curl | bash` does not auto-abort
