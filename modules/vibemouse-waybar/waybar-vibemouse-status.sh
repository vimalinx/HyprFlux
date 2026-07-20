#!/usr/bin/env bash
set -euo pipefail

rt="${XDG_RUNTIME_DIR:-/tmp}"
status_file="${VIBEMOUSE_STATUS_FILE:-}"
if [[ -z "$status_file" ]]; then
  for cand in "$rt/vibemouse-status.json" "$rt/vibemouse-gesture-status.json"; do
    [[ -f "$cand" ]] && { status_file="$cand"; break; }
  done
fi

if [[ -z "${status_file:-}" || ! -f "$status_file" ]]; then
  printf '{"text":"","class":"idle","tooltip":"VibeMouse idle"}\n'
  exit 0
fi

python3 - "$status_file" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as fh:
        payload = json.load(fh)
except Exception:
    print('{"text":"","class":"idle","tooltip":"VibeMouse idle"}')
    raise SystemExit(0)

state = str(payload.get("state") or "").lower()
if state == "processing":
    klass, text, label = "processing", " …", "transcribing"
elif state == "recording" or bool(payload.get("recording")):
    klass, text, label = "recording", " REC", "recording"
else:
    klass, text, label = "idle", "", "idle"

profile = str(payload.get("profile") or "").strip() or "unknown"
tooltip = f"VibeMouse {label} · ASR {profile}"

print(json.dumps({"text": text, "class": klass, "tooltip": tooltip}, ensure_ascii=False))
PY
