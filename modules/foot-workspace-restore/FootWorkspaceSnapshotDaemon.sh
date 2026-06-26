#!/usr/bin/env bash

set -euo pipefail

SAVE_SCRIPT="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserScripts/SaveFootWorkspaceSnapshot.sh"
INITIAL_DELAY="${FOOT_WORKSPACE_SNAPSHOT_INITIAL_DELAY:-45}"
INTERVAL="${FOOT_WORKSPACE_SNAPSHOT_INTERVAL:-60}"
LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}/foot-workspace-snapshot-daemon.lock"
PID_FILE="${LOCK_DIR}/pid"

cleanup() {
  rm -f "$PID_FILE" 2>/dev/null || true
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    exit 0
  fi

  rm -rf "$LOCK_DIR"
  mkdir "$LOCK_DIR"
fi

printf '%s\n' "$$" > "$PID_FILE"
trap cleanup EXIT INT TERM

sleep "$INITIAL_DELAY"

while :; do
  "$SAVE_SCRIPT" >/dev/null 2>&1 || true
  sleep "$INTERVAL"
done
