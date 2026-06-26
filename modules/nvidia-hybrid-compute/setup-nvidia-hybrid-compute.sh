#!/usr/bin/env bash
set -euo pipefail

echo "=== NVIDIA hybrid compute setup ==="
echo
echo "This script requests supergfxctl Hybrid mode and leaves Hyprland on the iGPU."
echo "It does not write AQ_DRM_DEVICES and does not install modprobe files."
echo

if ! command -v supergfxctl >/dev/null 2>&1; then
  echo "supergfxctl not found" >&2
  exit 1
fi

current_mode="$(timeout 5s supergfxctl -g 2>/dev/null || echo Unknown)"
echo "Current mode: $current_mode"

if [ "$current_mode" != "Hybrid" ]; then
  output="$(timeout 5s supergfxctl -m Hybrid 2>&1 || true)"
  printf '%s\n' "$output"
  if printf '%s' "$output" | grep -qi "logout required"; then
    echo "Hybrid mode was requested; log out and back in to complete it."
  fi
else
  echo "Already in Hybrid mode."
fi

echo
echo "Expected policy:"
echo "- Normal GUI apps: Intel/Mesa"
echo "- CUDA/compute workloads: NVIDIA"
echo "- Explicit NVIDIA GUI offload: per-command only"
