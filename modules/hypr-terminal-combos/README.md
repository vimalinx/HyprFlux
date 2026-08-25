# Hypr Terminal Combos

Named terminal-combination store with idempotent restore for Hyprland. Captures sets of terminal windows and restores missing ones without closing existing ones.

This is the public-safe script surface used by Action Desk's Terminals tab. The full Action Desk UI lives in OKF / your desktop Quickshell tree; this module only ships the CLI/script.

## Files

- `TerminalCombos.py`

## Apply

```bash
cp TerminalCombos.py ~/.config/hypr/UserScripts/
chmod +x ~/.config/hypr/UserScripts/TerminalCombos.py
```

```bash
python3 ~/.config/hypr/UserScripts/TerminalCombos.py list
python3 ~/.config/hypr/UserScripts/TerminalCombos.py capture --name "work"
python3 ~/.config/hypr/UserScripts/TerminalCombos.py restore "work"
python3 ~/.config/hypr/UserScripts/TerminalCombos.py upsert-tmux \
  --name "AIOS project" --session "aios-project" --cwd "$PWD" --workspace 20 --mode dual
```

`upsert-tmux` is the Worksite integration boundary. It writes a combination containing exactly
one named tmux session and never captures unrelated terminal windows.

State is stored under `~/.local/state/hypr/terminal-combos.json` by the script; do not hand-edit that file while a restore is running.
