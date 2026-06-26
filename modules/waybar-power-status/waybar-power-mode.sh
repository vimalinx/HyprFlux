#!/usr/bin/env bash
set -euo pipefail

tlp_profile="unknown"
platform_profile="unknown"

if command -v tlpctl >/dev/null 2>&1; then
  tlp_profile="$(tlpctl get 2>/dev/null || true)"
fi

if [ -r /sys/firmware/acpi/platform_profile ]; then
  platform_profile="$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || true)"
fi

case "$platform_profile" in
  quiet)
    class_name="quiet"
    label="Quiet"
    expected_tlp="power-saver"
    ;;
  balanced)
    class_name="balanced"
    label="Balanced"
    expected_tlp="balanced"
    ;;
  performance)
    class_name="performance"
    label="Performance"
    expected_tlp="performance"
    ;;
  *)
    class_name="unknown"
    label="$platform_profile"
    expected_tlp="unknown"
    ;;
esac

printf '{"class":"%s","text":"%s","tooltip":"ASUS/TLP Power Mode\\nMode: %s\\nTLP: %s\\nExpected TLP: %s\\nPlatform: %s\\nClick: cycle profile"}\n' \
  "$class_name" "$label" "$label" "$tlp_profile" "$expected_tlp" "$platform_profile"
