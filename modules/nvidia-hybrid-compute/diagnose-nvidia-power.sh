#!/usr/bin/env bash
set -euo pipefail

echo "=== NVIDIA power evidence ==="
echo

if command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi:"
  nvidia-smi --query-gpu=name,driver_version,power.draw,power.limit --format=csv,noheader,nounits 2>/dev/null || true
  echo
fi

if command -v supergfxctl >/dev/null 2>&1; then
  echo "supergfxctl mode: $(supergfxctl -g 2>/dev/null || echo unknown)"
  echo "supergfxctl state: $(supergfxctl -S 2>/dev/null || echo unknown)"
  echo
fi

for path in /sys/bus/pci/devices/*/vendor; do
  [ -r "$path" ] || continue
  dev_dir="$(dirname "$path")"
  if [ "$(cat "$path" 2>/dev/null)" = "0x10de" ]; then
    printf '%s runtime_status=' "$dev_dir"
    cat "$dev_dir/power/runtime_status" 2>/dev/null || echo unknown
  fi
done

echo
echo "Tip: querying nvidia-smi can wake the dGPU on some laptops. Confirm runtime_status and active clients before blaming the dGPU for drain."
