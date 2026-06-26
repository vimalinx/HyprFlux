#!/usr/bin/env bash
set -euo pipefail

echo "=== NVIDIA compute status ==="
echo

echo "1. supergfxctl"
if command -v supergfxctl >/dev/null 2>&1; then
  echo "   mode: $(supergfxctl -g 2>/dev/null || echo unknown)"
  echo "   state: $(supergfxctl -S 2>/dev/null || echo unknown)"
else
  echo "   supergfxctl not found"
fi
echo

echo "2. NVIDIA driver"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null || echo "   nvidia-smi could not read the GPU"
else
  echo "   nvidia-smi not found"
fi
echo

echo "3. CUDA toolkit"
if command -v nvcc >/dev/null 2>&1; then
  nvcc --version | awk '/release/ { print "   nvcc: " $0 }'
else
  echo "   nvcc not found"
fi
echo

echo "4. Python CUDA"
if command -v python >/dev/null 2>&1; then
  python - <<'PY' 2>/dev/null || echo "   Python CUDA check skipped or failed"
try:
    import torch
    print(f"   PyTorch: {torch.__version__}")
    print(f"   CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"   CUDA device: {torch.cuda.get_device_name(0)}")
except ImportError:
    print("   PyTorch not installed")
PY
else
  echo "   python not found"
fi
echo

echo "5. Current OpenGL renderer"
if command -v glxinfo >/dev/null 2>&1; then
  glxinfo 2>/dev/null | awk -F': ' '/OpenGL renderer/ { print "   " $2; exit }' || true
else
  echo "   glxinfo not found"
fi
