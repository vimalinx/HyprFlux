#!/usr/bin/env bash

set -euo pipefail

HYPRCTL_BIN="$(command -v "${HYPRCTL_BIN:-hyprctl}" 2>/dev/null || true)"
PS_BIN="$(command -v "${PS_BIN:-ps}" 2>/dev/null || true)"
TMUX_BIN="$(command -v "${TMUX_BIN:-tmux}" 2>/dev/null || true)"
PROC_ROOT="${PROC_ROOT:-/proc}"
ALLOWLIST_FILE="${ALLOWLIST_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserScripts/foot-workspace-allowlist.conf}"
SNAPSHOT_PATH="${SNAPSHOT_PATH:-${XDG_STATE_HOME:-$HOME/.local/state}/hypr/foot-workspace-snapshot.json}"

declare -A CHILDREN=()
declare -A COMMS=()
declare -A ARGS=()
declare -A HASH_COUNTS=()
declare -A TMUX_CLIENT_SESSIONS=()
declare -A TMUX_SESSION_CWDS=()

is_shell() {
  case "${1-}" in
    bash | dash | fish | sh | zsh) return 0 ;;
    *) return 1 ;;
  esac
}

allowlist_pattern() {
  if [ -f "$ALLOWLIST_FILE" ]; then
    grep -v '^[[:space:]]*#' "$ALLOWLIST_FILE" |
      sed '/^[[:space:]]*$/d' |
      paste -sd'|' -
  else
    printf '%s' 'codex|btop|openclaw'
  fi
}

command_allowed() {
  local comm="${1-}"
  local args="${2-}"
  local pattern="${3-}"

  [ -n "$pattern" ] || return 1
  printf '%s\n%s\n' "$comm" "$args" | rg -qi --pcre2 "$pattern"
}

load_process_table() {
  local pid=""
  local ppid=""
  local comm=""
  local args=""

  while read -r pid ppid comm args; do
    [ -n "$pid" ] || continue
    COMMS["$pid"]="$comm"
    ARGS["$pid"]="${args:-}"
    CHILDREN["$ppid"]="${CHILDREN[$ppid]:-} $pid"
  done < <("$PS_BIN" -eo pid=,ppid=,comm=,args=)
}

load_tmux_table() {
  local client_pid=""
  local session_name=""
  local pane_active=""
  local pane_cwd=""

  [ -n "$TMUX_BIN" ] || return 0

  while IFS='|' read -r client_pid session_name; do
    [ -n "$client_pid" ] || continue
    [ -n "$session_name" ] || continue
    TMUX_CLIENT_SESSIONS["$client_pid"]="$session_name"
  done < <("$TMUX_BIN" list-clients -F '#{client_pid}|#{session_name}' 2>/dev/null || true)

  while IFS='|' read -r session_name pane_active pane_cwd; do
    [ -n "$session_name" ] || continue
    [ -n "$pane_cwd" ] || continue

    if [ "${pane_active:-0}" = "1" ] || [ -z "${TMUX_SESSION_CWDS[$session_name]:-}" ]; then
      TMUX_SESSION_CWDS["$session_name"]="$pane_cwd"
    fi
  done < <("$TMUX_BIN" list-panes -a -F '#{session_name}|#{?pane_active,1,0}|#{pane_current_path}' 2>/dev/null || true)
}

read_cwd() {
  local pid="${1-}"

  [ -n "$pid" ] || return 1
  [ -e "$PROC_ROOT/$pid/cwd" ] || return 1
  readlink "$PROC_ROOT/$pid/cwd" 2>/dev/null || return 1
}

find_tmux_client_pid() {
  local parent_pid="${1-}"
  local -a queue=()
  local idx=0
  local pid=""
  local child=""

  [ -n "$parent_pid" ] || return 1
  queue+=("$parent_pid")

  while [ "$idx" -lt "${#queue[@]}" ]; do
    pid="${queue[$idx]}"
    idx=$((idx + 1))

    if [ -n "${TMUX_CLIENT_SESSIONS[$pid]:-}" ]; then
      printf '%s' "$pid"
      return 0
    fi

    for child in ${CHILDREN[$pid]:-}; do
      queue+=("$child")
    done
  done

  return 1
}

find_command_parent_pid() {
  local foot_pid="${1-}"
  local child=""

  for child in ${CHILDREN[$foot_pid]:-}; do
    if is_shell "${COMMS[$child]:-}"; then
      printf '%s' "$child"
      return 0
    fi
  done

  printf '%s' "$foot_pid"
}

resolve_cmd() {
  local pid="${1-}"
  local raw_cmd="${2-}"
  local first_word=""
  local proc_path=""
  local resolved=""

  first_word="${raw_cmd%% *}"

  case "$first_word" in
    */*) printf '%s' "$raw_cmd"; return 0 ;;
  esac

  if [ -r "$PROC_ROOT/$pid/environ" ]; then
    proc_path="$(tr '\0' '\n' < "$PROC_ROOT/$pid/environ" 2>/dev/null | sed -n 's/^PATH=//p' | head -1)" || true
  fi

  if [ -n "$proc_path" ]; then
    local IFS=':'
    local dir=""
    for dir in $proc_path; do
      if [ -x "$dir/$first_word" ]; then
        resolved="$dir/$first_word"
        break
      fi
    done
  fi

  if [ -n "$resolved" ]; then
    if [ "$first_word" = "$raw_cmd" ]; then
      printf '%s' "$resolved"
    else
      printf '%s' "$resolved ${raw_cmd#* }"
    fi
    return 0
  fi

  printf '%s' "$raw_cmd"
}

find_target_pid() {
  local parent_pid="${1-}"
  local pattern="${2-}"
  local -a queue=()
  local idx=0
  local pid=""
  local child=""

  for child in ${CHILDREN[$parent_pid]:-}; do
    queue+=("$child")
  done

  while [ "$idx" -lt "${#queue[@]}" ]; do
    pid="${queue[$idx]}"
    idx=$((idx + 1))

    if ! is_shell "${COMMS[$pid]:-}" && command_allowed "${COMMS[$pid]:-}" "${ARGS[$pid]:-}" "$pattern"; then
      printf '%s' "$pid"
      return 0
    fi

    for child in ${CHILDREN[$pid]:-}; do
      queue+=("$child")
    done
  done

  return 1
}

stable_hash() {
  local value="${1-}"

  if command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$value" | sha1sum | awk '{print substr($1, 1, 12)}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$value" | shasum | awk '{print substr($1, 1, 12)}'
  else
    printf '%s' "$value" | cksum | awk '{print $1}'
  fi
}

build_snapshot_tag() {
  local prefix="${1-}"
  local hash_key="${2-}"
  local hash_value=""
  local count=0

  hash_value="$(stable_hash "$hash_key")"
  count="${HASH_COUNTS[$hash_value]:-0}"
  count=$((count + 1))
  HASH_COUNTS["$hash_value"]="$count"

  printf '%s-%s-%s' "$prefix" "$hash_value" "$count"
}

snapshot_entries() {
  local pattern=""
  local foot_pid=""
  local workspace=""
  local title=""
  local xdg_tag=""
  local command_parent_pid=""
  local target_pid=""
  local cwd=""
  local cmd=""
  local hash_key=""
  local tag=""
  local tmux_client_pid=""
  local tmux_session=""

  pattern="$(allowlist_pattern)"

  "$HYPRCTL_BIN" clients -j 2>/dev/null |
    jq -r '.[] | select(.class == "foot" and ((.xdgTag // "") | startswith("tmux-ws-") | not)) | [(.pid | tostring), .workspace.name, (.title // ""), (.xdgTag // "")] | @tsv' |
    sort -t $'\t' -k2,2 -k3,3 -k1,1n |
    while IFS=$'\t' read -r foot_pid workspace title xdg_tag; do
      if tmux_client_pid="$(find_tmux_client_pid "$foot_pid")"; then
        tmux_session="${TMUX_CLIENT_SESSIONS[$tmux_client_pid]:-}"
        [ -n "$tmux_session" ] || continue

        cwd="${TMUX_SESSION_CWDS[$tmux_session]:-}"
        [ -n "$cwd" ] || cwd="$(read_cwd "$tmux_client_pid" || true)"
        [ -n "$cwd" ] || cwd="$HOME"

        if [ -z "$title" ] || [ "$title" = "Foot" ]; then
          title="tmux:${tmux_session}"
        fi

        printf -v cmd 'tmux new-session -A -s %q' "$tmux_session"

        tag="$xdg_tag"
        if [ -z "$tag" ]; then
          hash_key="tmux|${workspace}|${title}|${tmux_session}|${cwd}"
          tag="$(build_snapshot_tag "saved-tmux" "$hash_key")"
        fi

        jq -cn \
          --arg workspace "$workspace" \
          --arg title "$title" \
          --arg cwd "$cwd" \
          --arg cmd "$cmd" \
          --arg tag "$tag" \
          '{workspace: $workspace, title: $title, cwd: $cwd, cmd: $cmd, tag: $tag}'
        continue
      fi

      command_parent_pid="$(find_command_parent_pid "$foot_pid")"

      if ! target_pid="$(find_target_pid "$command_parent_pid" "$pattern")"; then
        continue
      fi

      cmd="$(resolve_cmd "$target_pid" "${ARGS[$target_pid]:-${COMMS[$target_pid]:-}}")"
      [ -n "$cmd" ] || continue

      cwd="$(read_cwd "$target_pid" || true)"
      [ -n "$cwd" ] || cwd="$(read_cwd "$command_parent_pid" || true)"
      [ -n "$cwd" ] || cwd="$HOME"

      tag="$xdg_tag"
      if [ -z "$tag" ]; then
        hash_key="${workspace}|${title}|${cwd}|${cmd}"
        tag="$(build_snapshot_tag "saved-foot" "$hash_key")"
      fi

      jq -cn \
        --arg workspace "$workspace" \
        --arg title "$title" \
        --arg cwd "$cwd" \
        --arg cmd "$cmd" \
        --arg tag "$tag" \
        '{workspace: $workspace, title: $title, cwd: $cwd, cmd: $cmd, tag: $tag}'
    done
}

main() {
  local snapshot_dir=""
  local tmp_snapshot=""

  [ -n "$HYPRCTL_BIN" ] || exit 0
  [ -n "$PS_BIN" ] || exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  command -v rg >/dev/null 2>&1 || exit 0

  load_process_table
  load_tmux_table

  snapshot_dir="$(dirname "$SNAPSHOT_PATH")"
  mkdir -p "$snapshot_dir"
  tmp_snapshot="$(mktemp "${SNAPSHOT_PATH}.XXXXXX")"

  snapshot_entries | jq -s '.' > "$tmp_snapshot"
  mv "$tmp_snapshot" "$SNAPSHOT_PATH"
}

main "$@"
