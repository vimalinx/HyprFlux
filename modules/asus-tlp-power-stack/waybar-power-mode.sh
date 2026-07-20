#!/usr/bin/env bash
# Waybar ASUS/TLP power mode indicator. Click uses the authoritative stack.

set -euo pipefail

TLP_PROFILE="unknown"
PLATFORM_PROFILE="unknown"

if command -v tlpctl >/dev/null 2>&1; then
    TLP_PROFILE="$(tlpctl get 2>/dev/null || true)"
fi

if [ -r /sys/firmware/acpi/platform_profile ]; then
    PLATFORM_PROFILE="$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || true)"
fi

case "$PLATFORM_PROFILE" in
    quiet)
        CLASS="quiet"
        LABEL="Quiet"
        EXPECTED_TLP="power-saver"
        ;;
    balanced)
        CLASS="balanced"
        LABEL="Balanced"
        EXPECTED_TLP="balanced"
        ;;
    performance)
        CLASS="performance"
        LABEL="Performance"
        EXPECTED_TLP="performance"
        ;;
    *)
        CLASS="unknown"
        LABEL="$PLATFORM_PROFILE"
        EXPECTED_TLP="unknown"
        ;;
esac

printf '{"class":"%s","text":"","tooltip":"ASUS/TLP Power Mode\\nMode: %s\\nTLP: %s\\nExpected TLP: %s\\nPlatform: %s\\nClick: switch profile (Fn+F5 / Super+Alt+P)"}\n' \
    "$CLASS" "$LABEL" "$TLP_PROFILE" "$EXPECTED_TLP" "$PLATFORM_PROFILE"
