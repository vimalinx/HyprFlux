# HyprFlux Overview

HyprFlux is a desktop-customization collection extracted from a real Hyprland workstation. The goal is to preserve working tweaks as small, auditable modules that can be reused without exposing private shell configuration, machine-specific aliases, credentials, or complete dotfiles.

## Design Rules

- Module-first: every tweak lives under `modules/<name>/`.
- Read-only by default: there is no top-level script that overwrites a desktop session.
- Public-safe: snippets should avoid private paths, provider keys, cookies, session files, and personal shell startup files.
- Operational notes included: modules that can increase CPU, memory, or startup pressure document that explicitly.
- Current-state snapshots, not universal packages: these modules are practical references that may need adaptation.

## Extraction Source

The initial modules were extracted from local Hyprland, Waybar, PipeWire, tmux, systemd user, and Codex notification configuration on an Arch/Hyprland machine.

Private files were not copied wholesale. Shell startup files such as `.bashrc` and `.zshrc` were treated as unsafe sources and only safe ideas were represented as standalone snippets or documentation.

The second pass added NVIDIA hybrid-compute and system-power modules from live, read-only evidence: GUI-on-iGPU environment settings, NVIDIA compute/runtime-PM templates, ASUS/TLP profile mapping, Waybar power status, battery-aware Hypridle behavior, and an optional low-power lid service.
