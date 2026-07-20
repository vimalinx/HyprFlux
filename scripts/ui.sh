#!/usr/bin/env bash
# Shared ANSI UI helpers for HyprFlux installer / session scripts.

if [[ "${HYPRFLUX_UI_LOADED:-0}" == "1" ]]; then
  return 0 2>/dev/null || true
fi
HYPRFLUX_UI_LOADED=1

HF_BOLD=$'\033[1m'
HF_DIM=$'\033[2m'
HF_RESET=$'\033[0m'
HF_CYAN=$'\033[38;2;88;196;221m'
HF_BLUE=$'\033[38;2;69;133;186m'
HF_GREEN=$'\033[38;2;142;192;124m'
HF_AMBER=$'\033[38;2;232;176;84m'
HF_ROSE=$'\033[38;2;232;116;132m'
HF_TEXT=$'\033[38;2;220;224;232m'
HF_MUTED=$'\033[38;2;140;150;168m'

hf_supports_color() {
  [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]] && [[ "${TERM:-}" != "dumb" ]]
}

if ! hf_supports_color; then
  HF_BOLD=""; HF_DIM=""; HF_RESET=""
  HF_CYAN=""; HF_BLUE=""; HF_GREEN=""; HF_AMBER=""; HF_ROSE=""; HF_TEXT=""; HF_MUTED=""
fi

hf_banner() {
  cat <<EOF
${HF_CYAN}${HF_BOLD}
  ┌──────────────────────────────────────────────┐
  │                                              │
  │   H y p r F l u x                            │
  │   ${HF_TEXT}desktop flux for Arch + Hyprland${HF_CYAN}         │
  │                                              │
  └──────────────────────────────────────────────┘
${HF_RESET}
EOF
}

hf_section() {
  printf '\n%s▸ %s%s\n' "$HF_BLUE$HF_BOLD" "$1" "$HF_RESET"
}

hf_info() {
  printf '  %s•%s %s%s%s\n' "$HF_CYAN" "$HF_RESET" "$HF_TEXT" "$1" "$HF_RESET"
}

hf_ok() {
  printf '  %s✓%s %s\n' "$HF_GREEN" "$HF_RESET" "$1"
}

hf_warn() {
  printf '  %s!%s %s\n' "$HF_AMBER" "$HF_RESET" "$1"
}

hf_err() {
  printf '  %s✗%s %s\n' "$HF_ROSE" "$HF_RESET" "$1" >&2
}

hf_step() {
  local current="$1" total="$2" label="$3"
  printf '  %s[%s/%s]%s %s\n' "$HF_DIM" "$current" "$total" "$HF_RESET" "$label"
}

hf_kv() {
  printf '  %s%-14s%s %s\n' "$HF_MUTED" "$1" "$HF_RESET$HF_TEXT" "$2$HF_RESET"
}

hf_box_line() {
  printf '  %s%s%s\n' "$HF_MUTED" "$1" "$HF_RESET"
}
