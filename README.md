# HyprFlux

<div align="center">

**Curated desktop flux for Arch Linux + Hyprland**

[Install](#install) · [Profiles](#profiles) · [Modules](#modules) · [Safety](docs/safety.md)

</div>

---

HyprFlux packages the reusable pieces of a real Arch + Hyprland workstation as small, auditable modules. It does **not** dump private dotfiles.

## Install

One-liner (landing page: [arch.vimalinx.com](https://arch.vimalinx.com)):

```bash
bash <(curl -fsSL https://arch.vimalinx.com/install)
```

缺 `git` 等依赖时会自动 `sudo` 安装并提示管理员密码。确认提示从真实终端读取，避免 `curl | bash` 管道误触退出。

兼容写法：

```bash
curl -fsSL https://arch.vimalinx.com/install | bash
```

Non-interactive / force generic power stack:

```bash
HF_YES=1 curl -fsSL https://arch.vimalinx.com/install | bash
HF_PROFILE=generic HF_YES=1 curl -fsSL https://arch.vimalinx.com/install | bash
```

Or clone and run locally:

```bash
git clone https://github.com/vimalinx/HyprFlux.git
cd HyprFlux
./install.sh
```

Useful flags:

```bash
./install.sh --dry-run          # show the plan only
./install.sh --profile generic  # force non-ASUS power stack
./install.sh --profile asus     # force ASUS stack
./install.sh --with-optional    # include optional modules
./install.sh -y                 # non-interactive
```

The installer:

1. Detects ASUS vs non-ASUS hardware.
2. Applies `profiles/common.modules` plus either `asus` or `generic`.
3. Installs a session-start script with a clean startup banner (interactive) / quiet Hyprland `exec-once` path.
4. Backs up colliding files as `*.hyprflux-bak.<timestamp>` before overwrite.

After install, source the startup snippet from your Hyprland startup file:

```conf
source = $UserConfigs/HyprFluxStartup.conf
```

## Profiles

| Profile | When | Power stack |
|---|---|---|
| `asus` | ASUSTeK / ROG / TUF / Zephyrus, or live `asusd` | `asus-tlp-power-stack`, `asus-fan-mode`, ASUS Waybar power widgets |
| `generic` | everything else | `generic-power-stack` (`powerprofilesctl` or `tlpctl`) |

Non-ASUS machines never auto-start the ASUS helpers, even if those scripts happen to exist on disk.

## Modules

See [docs/module-index.md](docs/module-index.md) for the full list. Highlights added in this refresh:

- Dual-monitor workspace banks
- Wayland compositor OOM protection
- Terminal combos + session button
- VibeMouse Waybar status
- RNNoise / Clear Voice mic stacks
- Generic power stack for non-ASUS laptops
- Action Desk-aware Quickshell on-demand launcher

## Checks

```bash
./scripts/check.sh
```

## Design

- Module-first under `modules/<name>/`
- Read-only by default unless you run `./install.sh`
- Public-safe: no shell rc dumps, no API keys, no private agent services
- Snippets for keybinds / Waybar still need a manual merge where noted in each module README
