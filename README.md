# HyprFlux

Curated desktop flux for an Arch Linux + Hyprland workstation.

HyprFlux is a public collection of the small desktop customizations that proved useful on my daily Hyprland setup. It keeps the reusable parts, templates, and notes, instead of publishing a full private dotfiles dump.

## What Is Included

- Codex task completion notifications with project and workspace context.
- Reversed Hyprland and Waybar workspace scroll direction.
- A low-power Waybar CAVA visualizer that stays idle until audio is playing.
- A Waybar desktop-agent status module for Codex, Claude Code, OMP, OpenClaw, Hermes, and browser agents.
- A PipeWire low-gain virtual microphone for clipping-safe calls and recording.
- Tmux status styling from a Wallust/Kitty palette.
- Optional foot/tmux workspace restore scripts.
- Clipboard history as user systemd services.
- A Caffeine-ng autostart disable override for Waybar idle inhibitor users.

## Layout

```text
modules/
  codex-task-notify/
  hypr-workspace-scroll/
  waybar-workspace-scroll/
  waybar-cava-lowpower/
  waybar-agent-status/
  safe-mic-lowgain/
  tmux-wallust/
  foot-workspace-restore/
  clipboard-systemd/
  caffeine-disable/
docs/
  module-index.md
  overview.md
  safety.md
scripts/
  check.sh
```

## Use

Pick a module, read its `README.md`, then copy or adapt only that module's files into your own dotfiles.

This repository intentionally does not ship a global installer. Several modules touch session startup, audio routing, or status-bar process scanning, so they should be applied one at a time.

Run checks before committing changes:

```bash
./scripts/check.sh
```

## External Project

The Codex notifier is maintained as a standalone program:

```text
https://github.com/vimalinx/codex-task-notify
```

HyprFlux includes integration notes and config snippets for using it as part of the desktop setup.

## Compatibility

This collection targets:

- Arch Linux or Arch-based systems.
- Hyprland.
- Waybar.
- PipeWire + WirePlumber.
- foot, tmux, jq, ripgrep, playerctl, and systemd user services for selected modules.

Each module documents its own dependencies.
