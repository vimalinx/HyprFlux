#!/usr/bin/env bash
# Waybar power-mode indicator for non-ASUS machines.

set -euo pipefail

PROFILE="unknown"
BACKEND="none"

if command -v powerprofilesctl >/dev/null 2>&1; then
  BACKEND="ppd"
  PROFILE="$(powerprofilesctl get 2>/dev/null || true)"
elif command -v tlpctl >/dev/null 2>&1; then
  BACKEND="tlp"
  PROFILE="$(tlpctl get 2>/dev/null || true)"
fi

case "$PROFILE" in
  power-saver|powersave)
    CLASS="quiet"
    LABEL="Power Saver"
    ;;
  balanced)
    CLASS="balanced"
    LABEL="Balanced"
    ;;
  performance)
    CLASS="performance"
    LABEL="Performance"
    ;;
  *)
    CLASS="unknown"
    LABEL="${PROFILE:-unknown}"
    ;;
esac

printf '{"class":"%s","text":"","tooltip":"Generic Power Mode\\nBackend: %s\\nProfile: %s\\nClick: cycle profile"}\n' \
  "$CLASS" "$BACKEND" "$LABEL"
