# HyprFlux Overview

HyprFlux is a desktop-customization collection extracted from a real Hyprland workstation. The goal is to preserve working tweaks as small, auditable modules that can be reused without exposing private shell configuration, machine-specific aliases, credentials, or complete dotfiles.

## Design Rules

- Module-first: every tweak lives under `modules/<name>/`.
- Installer is explicit: `./install.sh` applies a profile; there is no silent global overwrite daemon.
- Profile-aware: ASUS machines get the ASUS power/fan stack; everyone else gets `generic-power-stack`.
- Public-safe: snippets should avoid private paths, provider keys, cookies, session files, and personal shell startup files.
- Operational notes included: modules that can increase CPU, memory, or startup pressure document that explicitly.
- Current-state snapshots, not universal packages: these modules are practical references that may need adaptation.

## Extraction Source

Modules were extracted from local Hyprland, Waybar, PipeWire, tmux, systemd user, Quickshell, and related desktop helpers on an Arch/Hyprland machine.

Private files were not copied wholesale. Shell startup files such as `.bashrc` and `.zshrc` were treated as unsafe sources and only safe ideas were represented as standalone snippets or documentation.

## Refresh history

1. Initial modules: notifications, workspace scroll, CAVA, agent status, safe mic, and polish snippets.
2. NVIDIA hybrid-compute and ASUS/TLP power modules from live read-only evidence.
3. Desktop polish: wallpaper, Fcitx/WeChat, Quickshell on-demand, Satty, Waydroid clipboard, SwayNC, SDDM, window rules.
4. Low-level policy: systemd memory guards, kernel powersave templates, Mesa EGL drop-in.
5. **2026-07-20 refresh:** backfill live ASUS/power/memory/Quickshell scripts; add dual-monitor workspaces, Wayland OOM protection, terminal combos, session button, VibeMouse Waybar, RNNoise/Clear Voice; introduce ASUS vs generic profiles with a pretty installer and session-start UI.
