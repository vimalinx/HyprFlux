#!/usr/bin/env bash
set -euo pipefail

qs_log_rules="${QS_LOG_RULES:-*.info=false;*.debug=false}"

start_qs() {
  if qs list 2>/dev/null | grep -q '^Instance '; then
    return 0
  fi
  qs --daemonize --log-rules "$qs_log_rules"
  sleep "${QS_START_DELAY:-0.45}"
}

case "${1:-}" in
  status-open)
    qs ipc call statusPanel open >/dev/null 2>&1 || {
      start_qs
      qs ipc call statusPanel open >/dev/null
    }
    ;;
  status-toggle)
    qs ipc call statusPanel toggle >/dev/null 2>&1 || {
      start_qs
      qs ipc call statusPanel open >/dev/null
    }
    ;;
  status-close)
    qs ipc call statusPanel close >/dev/null 2>&1 || true
    ;;
  overview-toggle)
    qs ipc call overview toggle >/dev/null 2>&1 || {
      start_qs
      qs ipc call overview open >/dev/null
    }
    ;;
  overview-open)
    qs ipc call overview open >/dev/null 2>&1 || {
      start_qs
      qs ipc call overview open >/dev/null
    }
    ;;
  quit)
    delay_ms="${2:-2200}"
    sleep "$(awk "BEGIN { printf \"%.3f\", $delay_ms / 1000 }")"
    qs kill 2>/dev/null || true
    ;;
  *)
    echo "usage: $0 {status-open|status-toggle|status-close|overview-toggle|overview-open|quit [delay_ms]}" >&2
    exit 2
    ;;
esac
