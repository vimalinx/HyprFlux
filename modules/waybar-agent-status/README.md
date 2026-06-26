# Waybar Agent Status

Waybar custom module that summarizes visible desktop agents from the current Hyprland session.

It scans Hyprland windows, walks process descendants, detects common local agent CLIs, and enriches Codex windows with local Codex thread/goal state when the SQLite state files are present.

## Detects

- Codex
- Claude Code
- OMP
- OpenClaw / opencode
- GenericAgent
- Hermes
- Browser pages with agent-related titles

## Dependencies

- `bash`
- `python3`
- `hyprctl`
- `ps`
- Optional Codex SQLite state under `~/.codex/`
- Optional Hermes state under `$HERMES_HOME` or `~/.hermes/`

## Apply

Copy the script:

```bash
mkdir -p ~/.config/hypr/scripts
cp waybar-agent-status.sh ~/.config/hypr/scripts/waybar-agent-status.sh
chmod +x ~/.config/hypr/scripts/waybar-agent-status.sh
```

Add the custom module:

```jsonc
"custom/agent_status": {
  "exec": "bash $HOME/.config/hypr/scripts/waybar-agent-status.sh",
  "return-type": "json",
  "interval": 5,
  "format": "{}",
  "tooltip": true
}
```

Then place `custom/agent_status` in one of your Waybar module arrays.

## Notes

This script reads local process metadata and desktop window titles. It is intended for personal desktop status bars, not multi-user hosts.
