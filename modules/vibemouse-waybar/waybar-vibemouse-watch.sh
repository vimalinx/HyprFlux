#!/usr/bin/env bash
# Instantly refresh waybar's VibeMouse module the moment the daemon writes its
# status file. waybar module "custom/vibemouse" is configured with signal:8,
# which maps to SIGRTMIN+8. No polling, no daemon changes.
set -u

rt="${XDG_RUNTIME_DIR:-/tmp}"
nudge() { pkill -SIGRTMIN+8 waybar 2>/dev/null || true; }

nudge   # correct the bar once on startup

inotifywait -q -m -e modify,close_write,create,moved_to "$rt" 2>/dev/null \
  | grep -E --line-buffered 'vibemouse(-gesture)?-status\.json' \
  | while read -r _; do nudge; done
