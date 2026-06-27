# Module Index

## codex-task-notify

Integration notes for `vimalinx/codex-task-notify`, a Codex CLI completion notifier that includes project and Hyprland workspace context.

## hypr-workspace-scroll

Hyprland keybind snippet that makes `SUPER + mouse wheel` match the preferred workspace direction.

## waybar-workspace-scroll

Waybar workspace module snippet with matching scroll direction for `hyprland/workspaces#numbers`.

## waybar-cava-lowpower

Waybar CAVA wrapper that emits a static bar when idle, starts CAVA only while audio is playing, and cleans up CAVA children when Waybar exits.

## waybar-agent-status

Waybar module that scans open Hyprland windows and process descendants to summarize visible desktop agents and Codex task state.

## safe-mic-lowgain

PipeWire filter-chain template that creates a low-gain virtual microphone source and optionally sets it as the default source.

## nvidia-hybrid-compute

Hybrid NVIDIA module where normal GUI apps use Intel/Mesa and the NVIDIA dGPU remains available for CUDA or explicit offload. Includes environment snippets, a Hyprland systemd unit drop-in, modprobe/TLP templates, and power evidence scripts.

## asus-tlp-power-stack

ASUS laptop profile stack for keeping `asusctl`, TLP/TLP-PD, Hyprland refresh, blur, CAVA, Wi-Fi powersave, Bluetooth idle state, and notifications aligned behind one profile toggle.

## systemd-memory-guard

User systemd slice drop-ins that pressure GUI app workloads earlier and protect the interactive Wayland session from whole-session kernel OOM events.

## kernel-power-hardening

Modprobe templates for HDA audio powersave, Intel Wi-Fi powersave, and disabling rarely used network protocol modules.

## waybar-power-status

Waybar custom modules for platform/TLP power mode and battery charge-limit display, plus an optional battery threshold toggle.

## hypridle-power-policy

Battery-aware Hypridle lock, DPMS, and suspend snippet. Suspends only when UPower reports the machine is discharging.

## low-power-lid-optional

Optional user service that blocks lid-close suspend only while a low-power profile is active. Disabled by default in the source setup.

## wallpaper-swww-restore

Robust `swww` wallpaper restore that starts the daemon, applies per-monitor wallpaper, keeps Rofi/Hyprland wallpaper pointers in sync, and reapplies when monitors change.

## fcitx-wechat-scale

Fcitx5 classic UI font scaler for WeChat focus plus a native WeChat HiDPI launcher that detects monitor scale and focuses an existing WeChat window.

## quickshell-on-demand

Quickshell helper that starts `qs` only when overview/status-panel IPC calls are needed, with keybind, gesture, and Waybar snippets.

## satty-screenshot

Annotated screenshot workflow using `hyprshot` and `satty`, plus optional GPU Screen Recorder keybind snippets.

## waydroid-clipboard

Host-to-Waydroid paste bridge that sends Wayland clipboard text through ADB Keyboard.

## swaync-igpu-systemd

SwayNC systemd user drop-in that keeps the notification daemon on Intel/Mesa and documents disabling direct Hyprland `exec-once = swaync` startup.

## sddm-intel-greeter

Optional SDDM X11 greeter template that pins the login greeter to Intel iGPU to avoid waking the NVIDIA card before session start.

## hypr-window-polish

Selected public-safe Hyprland window/layer snippets: fullscreen idle inhibit, picture-in-picture, dialogs, no-blur rules, layer blur, gestures, XWayland scaling, and cursor behavior.

## tmux-wallust

Tmux config snippet and theme script that read colors from a Kitty/Wallust palette without heavy status-line polling.

## foot-workspace-restore

Optional scripts for restoring selected foot/tmux windows to Hyprland workspaces. Disabled by default because it can add login-time memory and process pressure.

## clipboard-systemd

Systemd user units for text and image clipboard history, replacing duplicate `exec-once wl-paste` startup entries.

## caffeine-disable

Autostart override that disables Caffeine-ng when using Waybar's `idle_inhibitor` instead.
