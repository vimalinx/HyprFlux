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

Hybrid NVIDIA module where normal GUI apps use Intel/Mesa and the NVIDIA dGPU remains available for CUDA or explicit offload. Includes environment snippets, modprobe/TLP templates, and power evidence scripts.

## asus-tlp-power-stack

ASUS laptop profile stack for keeping `asusctl`, TLP/TLP-PD, Hyprland refresh, blur, CAVA, Wi-Fi powersave, Bluetooth idle state, and notifications aligned behind one profile toggle.

## waybar-power-status

Waybar custom modules for platform/TLP power mode and battery charge-limit display, plus an optional battery threshold toggle.

## hypridle-power-policy

Battery-aware Hypridle lock, DPMS, and suspend snippet. Suspends only when UPower reports the machine is discharging.

## low-power-lid-optional

Optional user service that blocks lid-close suspend only while a low-power profile is active. Disabled by default in the source setup.

## tmux-wallust

Tmux config snippet and theme script that read colors from a Kitty/Wallust palette without heavy status-line polling.

## foot-workspace-restore

Optional scripts for restoring selected foot/tmux windows to Hyprland workspaces. Disabled by default because it can add login-time memory and process pressure.

## clipboard-systemd

Systemd user units for text and image clipboard history, replacing duplicate `exec-once wl-paste` startup entries.

## caffeine-disable

Autostart override that disables Caffeine-ng when using Waybar's `idle_inhibitor` instead.
