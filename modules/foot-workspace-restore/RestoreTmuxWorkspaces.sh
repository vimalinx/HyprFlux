#!/usr/bin/env bash

set -euo pipefail

HYPRCTL_BIN="$(command -v "${HYPRCTL_BIN:-hyprctl}" 2>/dev/null || true)"
MAPPING_FILE="${TMUX_WORKSPACE_MAPPING_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserScripts/tmux-workspaces.conf}"
SAVED_FOOT_SNAPSHOT_FILE="${SNAPSHOT_PATH:-${XDG_STATE_HOME:-$HOME/.local/state}/hypr/foot-workspace-snapshot.json}"
SAVED_FOOT_SNAPSHOT_SCRIPT="${SAVED_FOOT_SNAPSHOT_SCRIPT:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserScripts/SaveFootWorkspaceSnapshot.sh}"
TERMINAL_BIN="$(command -v "${TERMINAL_BIN:-foot}" 2>/dev/null || true)"
SHELL_BIN="${SHELL:-/bin/zsh}"
STARTUP_DELAY="${TMUX_WORKSPACE_STARTUP_DELAY:-2}"

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

sanitize_tag() {
  printf '%s' "$1" | tr -cs '[:alnum:]._-' '-'
}

window_exists() {
  local tag="$1"
  "$HYPRCTL_BIN" clients -j 2>/dev/null | jq -e --arg tag "$tag" '.[] | select(.xdgTag == $tag)' >/dev/null
}

wait_for_hyprland() {
  local attempt

  for attempt in $(seq 1 20); do
    if "$HYPRCTL_BIN" activeworkspace >/dev/null 2>&1; then
      return 0
    fi

    sleep 0.5
  done

  return 1
}

launch_workspace_terminal() {
  local workspace="$1"
  local session="$2"
  local tag="$3"
  local inner_cmd=""
  local terminal_cmd=""

  printf -v inner_cmd 'exec tmux new-session -A -s %q' "$session"
  printf -v terminal_cmd '%q --toplevel-tag %q -T %q %q -lc %q' \
    "$TERMINAL_BIN" \
    "$tag" \
    "tmux:${session}" \
    "$SHELL_BIN" \
    "$inner_cmd"

  "$HYPRCTL_BIN" dispatch exec "[workspace ${workspace} silent] ${terminal_cmd}"
}

launch_saved_foot_window() {
  local workspace="$1"
  local title="$2"
  local cwd="$3"
  local cmd="$4"
  local tag="$5"
  local inner_cmd=""
  local terminal_cmd=""

  if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
    cwd="$HOME"
  fi

  inner_cmd="exec ${cmd}"
  printf -v terminal_cmd '%q --toplevel-tag %q -T %q -D %q -H %q -lc %q' \
    "$TERMINAL_BIN" \
    "$tag" \
    "$title" \
    "$cwd" \
    "$SHELL_BIN" \
    "$inner_cmd"

  "$HYPRCTL_BIN" dispatch exec "[workspace ${workspace} silent] ${terminal_cmd}"
}

restore_tmux_workspaces() {
  local workspace=""
  local session=""
  local tag=""

  [ -f "$MAPPING_FILE" ] || return 0

  while IFS='|' read -r workspace session; do
    workspace="$(trim "$workspace")"
    session="$(trim "$session")"

    if [ -z "$workspace" ] || [ -z "$session" ]; then
      continue
    fi

    case "$workspace" in
      \#*) continue ;;
    esac

    tag="tmux-ws-$(sanitize_tag "$workspace")-$(sanitize_tag "$session")"

    if window_exists "$tag"; then
      continue
    fi

    launch_workspace_terminal "$workspace" "$session" "$tag"
    sleep 0.4
  done < "$MAPPING_FILE"
}

restore_saved_foot_windows() {
  local row=""
  local workspace=""
  local title=""
  local cwd=""
  local cmd=""
  local tag=""
  local current_snapshot=""

  [ -f "$SAVED_FOOT_SNAPSHOT_FILE" ] || return 0

  if [ -x "$SAVED_FOOT_SNAPSHOT_SCRIPT" ]; then
    current_snapshot="$(mktemp)"
    SNAPSHOT_PATH="$current_snapshot" "$SAVED_FOOT_SNAPSHOT_SCRIPT" >/dev/null 2>&1 || true
  fi

  while IFS= read -r row; do
    workspace="$(printf '%s' "$row" | jq -r '.workspace // ""')"
    title="$(printf '%s' "$row" | jq -r '.title // ""')"
    cwd="$(printf '%s' "$row" | jq -r '.cwd // ""')"
    cmd="$(printf '%s' "$row" | jq -r '.cmd // ""')"
    tag="$(printf '%s' "$row" | jq -r '.tag // ""')"

    if [ -z "$workspace" ] || [ -z "$cmd" ] || [ -z "$tag" ]; then
      continue
    fi

    if window_exists "$tag"; then
      continue
    fi

    if [ -n "$current_snapshot" ] && jq -e --arg tag "$tag" '.[] | select(.tag == $tag)' "$current_snapshot" >/dev/null 2>&1; then
      continue
    fi

    launch_saved_foot_window "$workspace" "$title" "$cwd" "$cmd" "$tag"
    sleep 0.4
  done < <(jq -c '.[]' "$SAVED_FOOT_SNAPSHOT_FILE")

  if [ -n "$current_snapshot" ]; then
    rm -f "$current_snapshot"
  fi
}

main() {
  [ -n "$HYPRCTL_BIN" ] || exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  [ -n "$TERMINAL_BIN" ] || exit 0

  sleep "$STARTUP_DELAY"
  wait_for_hyprland || exit 0
  restore_tmux_workspaces
  restore_saved_foot_windows
}

main "$@"
