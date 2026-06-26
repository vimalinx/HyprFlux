#!/usr/bin/env bash
set -euo pipefail

target="${1:-/etc/tlp.d/01-asus-g16-power.conf}"
backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"

if [ ! -f "$target" ]; then
  echo "Missing TLP config: $target" >&2
  exit 1
fi

sudo cp "$target" "$backup"

tmp="$(mktemp)"
awk '
  BEGIN { done = 0 }
  /^TLP_PROFILE_AC=/ {
    print "TLP_PROFILE_AC=BAL"
    done = 1
    next
  }
  { print }
  END {
    if (!done) {
      print "TLP_PROFILE_AC=BAL"
    }
  }
' "$target" > "$tmp"

sudo install -m 0644 "$tmp" "$target"
rm -f "$tmp"

sudo tlp start || true

echo "Backup: $backup"
echo "Verification:"
tlpctl get 2>/dev/null || true
cat /sys/firmware/acpi/platform_profile 2>/dev/null || true
asusctl profile get 2>/dev/null || true
