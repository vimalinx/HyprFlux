#!/usr/bin/env bash
# HyprFlux session startup — pretty, profile-aware, non-blocking.
# Installed to ~/.config/hypr/UserScripts/hyprflux-session-start.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_HINT="${HYPRFLUX_ROOT:-}"
if [[ -z "$REPO_HINT" ]]; then
  for cand in \
    "$HOME/Projects/HyprFlux" \
    "$HOME/HyprFlux" \
    "$(dirname "$SCRIPT_DIR")/.."
  do
    if [[ -f "$cand/scripts/detect-vendor.sh" ]]; then
      REPO_HINT="$cand"
      break
    fi
  done
fi

if [[ -n "$REPO_HINT" && -f "$REPO_HINT/scripts/ui.sh" ]]; then
  # shellcheck source=/dev/null
  source "$REPO_HINT/scripts/ui.sh"
  # shellcheck source=/dev/null
  source "$REPO_HINT/scripts/detect-vendor.sh"
else
  # Minimal fallback UI when repo is not beside the installed script.
  hf_banner() { printf '\n  HyprFlux session\n\n'; }
  hf_section() { printf '▸ %s\n' "$1"; }
  hf_ok() { printf '  ✓ %s\n' "$1"; }
  hf_warn() { printf '  ! %s\n' "$1"; }
  hf_info() { printf '  • %s\n' "$1"; }
  hf_kv() { printf '  %-14s %s\n' "$1" "$2"; }
  hf_is_asus() {
    local vendor
    vendor="$(tr -d '\0' </sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
    [[ "$vendor" == *[Aa][Ss][Uu][Ss]* ]]
  }
  hf_detect_profile() { hf_is_asus && echo asus || echo generic; }
  hf_vendor_summary() {
    printf '%s / %s\n' \
      "$(tr -d '\0' </sys/class/dmi/id/sys_vendor 2>/dev/null || echo unknown)" \
      "$(tr -d '\0' </sys/class/dmi/id/product_name 2>/dev/null || echo unknown)"
  }
fi

LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyprflux"
LOG_FILE="$LOG_DIR/session-start.log"
mkdir -p "$LOG_DIR"

{
  printf '\n===== %s =====\n' "$(date -Is)"
} >>"$LOG_FILE"

# Pretty terminal UI when interactive, or when HYPRFLUX_FORCE_UI=1.
# Under Hyprland exec-once, stdout is usually not a TTY — use a desktop
# notification as the lightweight startup surface instead.
INTERACTIVE=0
[[ -t 1 || "${HYPRFLUX_FORCE_UI:-0}" == "1" ]] && INTERACTIVE=1

profile="$(hf_detect_profile)"
vendor_line="$(hf_vendor_summary)"

if [[ "$INTERACTIVE" == "1" ]]; then
  hf_banner
  hf_section "Session start"
  hf_kv "Vendor" "$vendor_line"
  hf_kv "Profile" "$profile"
elif command -v notify-send >/dev/null 2>&1; then
  notify-send -t 3500 "HyprFlux" "Session start · ${profile} · ${vendor_line}" || true
fi

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG_FILE"
}

run_soft() {
  local label="$1"
  shift
  if "$@" >>"$LOG_FILE" 2>&1; then
    log "OK  $label"
    [[ "$INTERACTIVE" == "1" ]] && hf_ok "$label"
  else
    log "SKIP/FAIL $label"
    [[ "$INTERACTIVE" == "1" ]] && hf_warn "$label (skipped)"
  fi
}

# Never block session start on a single helper.
run_soft_timeout() {
  local label="$1"
  local seconds="$2"
  shift 2
  if command -v timeout >/dev/null 2>&1; then
    run_soft "$label" timeout "$seconds" "$@"
  else
    run_soft "$label" "$@"
  fi
}

log "vendor=$vendor_line profile=$profile"

# Shared desktop services (idempotent enable --now is fine if already active).
if command -v systemctl >/dev/null 2>&1; then
  run_soft_timeout "cliphist" 5 systemctl --user start cliphist.service
  run_soft_timeout "cliphist-image" 5 systemctl --user start cliphist-image.service
fi

# Wallpaper monitor daemon — start once in background, never wait on it.
if [[ -x "$HOME/.config/hypr/scripts/MonitorWallpaperSync.sh" ]]; then
  if ! pgrep -f 'MonitorWallpaperSync\.sh' >/dev/null 2>&1; then
    nohup "$HOME/.config/hypr/scripts/MonitorWallpaperSync.sh" >>"$LOG_FILE" 2>&1 &
    disown || true
    log "OK  wallpaper sync daemon"
    [[ "$INTERACTIVE" == "1" ]] && hf_ok "wallpaper sync daemon"
  else
    log "OK  wallpaper sync already running"
    [[ "$INTERACTIVE" == "1" ]] && hf_ok "wallpaper sync already running"
  fi
fi

if [[ "$profile" == "asus" ]]; then
  [[ "$INTERACTIVE" == "1" ]] && hf_section "ASUS stack"
  if command -v asusctl >/dev/null 2>&1; then
    run_soft "asusctl present" true
  else
    log "asus profile selected but asusctl missing"
    [[ "$INTERACTIVE" == "1" ]] && hf_warn "asusctl not found"
  fi
  if [[ -x "$HOME/.config/hypr/UserScripts/toggle-asus-profile.sh" ]]; then
    run_soft "ASUS profile scripts ready" true
  fi
  log "generic-power-stack not started (ASUS machine)"
else
  [[ "$INTERACTIVE" == "1" ]] && hf_section "Generic power stack"
  if [[ -x "$HOME/.config/hypr/UserScripts/toggle-power-profile.sh" ]]; then
    run_soft "generic power scripts ready" true
  else
    [[ "$INTERACTIVE" == "1" ]] && hf_warn "toggle-power-profile.sh not installed"
  fi
  if [[ -x "$HOME/.config/hypr/UserScripts/toggle-asus-profile.sh" ]]; then
    log "NOTE: ASUS scripts exist on disk but will not be auto-started"
    [[ "$INTERACTIVE" == "1" ]] && hf_warn "ASUS scripts present but not started"
  fi
fi

# Optional mic stacks — start only if the user enabled the units.
if systemctl --user is-enabled rnnoise-mic.service >/dev/null 2>&1; then
  run_soft_timeout "rnnoise mic" 5 systemctl --user start rnnoise-mic.service
fi
if systemctl --user is-enabled clear-voice-mic.service >/dev/null 2>&1; then
  run_soft_timeout "clear-voice mic" 5 systemctl --user start clear-voice-mic.service
fi
if systemctl --user is-enabled safe-mic-lowgain.service >/dev/null 2>&1; then
  run_soft_timeout "safe-mic" 5 systemctl --user start safe-mic-lowgain.service
fi

[[ "$INTERACTIVE" == "1" ]] && hf_ok "HyprFlux session start finished"
log "session start finished"
exit 0
