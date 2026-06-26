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

## tmux-wallust

Tmux config snippet and theme script that read colors from a Kitty/Wallust palette without heavy status-line polling.

## foot-workspace-restore

Optional scripts for restoring selected foot/tmux windows to Hyprland workspaces. Disabled by default because it can add login-time memory and process pressure.

## clipboard-systemd

Systemd user units for text and image clipboard history, replacing duplicate `exec-once wl-paste` startup entries.

## caffeine-disable

Autostart override that disables Caffeine-ng when using Waybar's `idle_inhibitor` instead.
