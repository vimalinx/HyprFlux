# Module Index

## Power and laptop

### asus-tlp-power-stack

ASUS `asusctl` + TLP orchestrator, battery charge limit cycling, and Waybar power-mode scripts.

### asus-fan-mode

ASUS fan-curve helper for Waybar / keybinds.

### generic-power-stack

Non-ASUS power-profile cycling via `powerprofilesctl` or `tlpctl`, plus sysfs battery-limit toggle.

### waybar-power-status

Shared battery-limit Waybar display (`waybar_battery_limit.sh`) and integration snippets.

### low-power-lid-optional

Optional lid-close guard for quiet / power-saver sessions.

### hypridle-power-policy

Battery-aware Hypridle lock / DPMS / suspend snippet.

## GPU / memory / kernel

### nvidia-hybrid-compute

GUI-on-iGPU + CUDA-capable NVIDIA hybrid templates.

### systemd-memory-guard

User slice memory policy: protect `session.slice`, do not PSI-kill ordinary apps.

### wayland-oom-protection

Mark Hyprland compositor `ManagedOOMPreference=avoid`.

### kernel-power-hardening

Modprobe templates for audio / Wi-Fi powersave and rare protocol blacklists.

## Desktop UI

### quickshell-on-demand

Starts Quickshell on demand for Action Desk / status / overview / terminals IPC.

### hypr-terminal-combos

Named terminal combination capture / restore CLI.

### hypr-session-button

Hyprland session save / restore helper (+ autosave timer).

### dual-monitor-workspaces

Independent 1–10 workspace banks for laptop panel + side display.

### hypr-window-polish / hypr-workspace-scroll / waybar-workspace-scroll

Window rules, gestures, and matching workspace scroll direction.

### wallpaper-swww-restore

Robust `swww` restore and monitor-change reapply.

### satty-screenshot

Annotated screenshot workflow (+ optional GSR binds).

### swaync-igpu-systemd / sddm-intel-greeter

Keep notifications / greeter on iGPU where relevant.

### caffeine-disable

Disable Caffeine-ng when using Waybar idle inhibitor.

### vibemouse-waybar

Waybar module + watcher for VibeMouse recording state.

### waybar-cava-lowpower / waybar-agent-status

Low-power CAVA wrapper and desktop-agent summary module.

## Input / audio / apps

### fcitx-wechat-scale

Fcitx candidate scaler + HiDPI WeChat launcher.

### safe-mic-lowgain / rnnoise-mic / clear-voice-mic

Low-gain mic base plus optional RNNoise or WebRTC clear-voice chains.

### clipboard-systemd

cliphist text/image user services and optional `wl-copy` wrapper.

### waydroid-clipboard

Host → Waydroid paste bridge via ADB Keyboard.

### tmux-wallust / foot-workspace-restore

Tmux palette sync and optional foot/tmux workspace restore.

### codex-task-notify

Integration notes for the separate Codex completion notifier repo.
