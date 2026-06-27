#!/usr/bin/env bash
set -euo pipefail

config_file="${FCITX_CLASSICUI_CONF:-$HOME/.config/fcitx5/conf/classicui.conf}"
state_file="${XDG_CACHE_HOME:-$HOME/.cache}/fcitx5-wechat-candidate-scale.state"
script_name="$(basename "$0")"
normal_font="${NORMAL_FONT:-Adwaita Sans 10}"
wechat_font="${WECHAT_FONT:-Adwaita Sans 18}"

apply_profile() {
  local profile="$1"
  local font="$normal_font"

  if [[ "$profile" == "wechat" ]]; then
    font="$wechat_font"
  fi

  [ -f "$config_file" ] || return 0
  mkdir -p "$(dirname "$state_file")"
  if [[ -f "$state_file" ]] && [[ "$(cat "$state_file")" == "$profile" ]]; then
    return
  fi

  local tmp
  tmp="$(mktemp "${config_file}.XXXXXX")"
  awk -v font="$font" '
    /^Font=/ { print "Font=\"" font "\""; next }
    /^MenuFont=/ { print "MenuFont=\"" font "\""; next }
    { print }
  ' "$config_file" > "$tmp"
  mv "$tmp" "$config_file"

  busctl --user call org.fcitx.Fcitx5 \
    /controller org.fcitx.Fcitx.Controller1 \
    ReloadAddonConfig s classicui >/dev/null 2>&1 || true

  printf '%s\n' "$profile" > "$state_file"
}

active_class() {
  local payload
  payload="$(hyprctl activewindow -j 2>/dev/null || printf '{}\n')"
  jq -r '.class // empty' <<<"$payload" 2>/dev/null || true
}

sync_profile() {
  local class_name
  class_name="$(active_class || true)"
  if [[ "$class_name" == "wechat" ]]; then
    apply_profile "wechat"
  else
    apply_profile "normal"
  fi
}

subscribe() {
  local socket2="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
  [[ -S "$socket2" ]] || exit 1

  while true; do
    sync_profile || true
    while read -r line; do
      [[ "$line" =~ ^activewindow ]] || [[ "$line" =~ ^workspace ]] || [[ "$line" =~ ^focusedmon ]] || continue
      sync_profile || true
    done < <(
      python3 - "$socket2" <<'PY'
import socket
import sys

path = sys.argv[1]
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(path)
buffer = b""

while True:
    data = sock.recv(4096)
    if not data:
        break
    buffer += data
    while b"\n" in buffer:
        line, buffer = buffer.split(b"\n", 1)
        print(line.decode("utf-8", "replace"), flush=True)
PY
    )
    sleep 1
  done
}

if [[ "${1:-}" == "--listener" ]]; then
  subscribe
  exit 0
fi

if [[ "${1:-}" == "--set" ]]; then
  case "${2:-}" in
    wechat|normal) apply_profile "$2" ;;
    *) echo "Usage: $script_name --set {wechat|normal}" >&2; exit 1 ;;
  esac
  exit 0
fi

if ! pgrep -f "${script_name} --listener" >/dev/null 2>&1; then
  nohup "$0" --listener </dev/null >/dev/null 2>&1 &
fi

sync_profile
