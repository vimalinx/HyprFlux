#!/usr/bin/env bash
# HyprFlux one-line installer — https://arch.vimalinx.com/install
set -euo pipefail

HF_REPO_URL="${HF_REPO_URL:-https://github.com/vimalinx/HyprFlux.git}"
HF_REF="${HF_REF:-main}"
HF_DIR="${HF_DIR:-$HOME/HyprFlux}"
HF_PROFILE="${HF_PROFILE:-auto}"
HF_YES="${HF_YES:-0}"
HF_OPTIONAL="${HF_OPTIONAL:-0}"

BOLD=$'\033[1m'; RESET=$'\033[0m'
CYAN=$'\033[38;2;88;196;221m'
GREEN=$'\033[38;2;142;192;124m'
AMBER=$'\033[38;2;232;176;84m'
TEXT=$'\033[38;2;220;224;232m'

if [[ ! -t 1 || -n "${NO_COLOR:-}" ]]; then
  BOLD=""; RESET=""; CYAN=""; GREEN=""; AMBER=""; TEXT=""
fi

banner() {
  cat <<BANNER
${CYAN}${BOLD}
  ┌──────────────────────────────────────────────┐
  │   HyprFlux · one-line installer              │
  │   ${TEXT}arch.vimalinx.com${CYAN}                          │
  └──────────────────────────────────────────────┘
${RESET}
BANNER
}

info() { printf '  %s•%s %s\n' "$CYAN" "$RESET" "$1"; }
ok() { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
warn() { printf '  %s!%s %s\n' "$AMBER" "$RESET" "$1"; }

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

banner
need git
need bash

info "repo: $HF_REPO_URL ($HF_REF)"
info "target: $HF_DIR"

if [[ -d "$HF_DIR/.git" ]]; then
  info "existing checkout found — pulling $HF_REF"
  git -C "$HF_DIR" fetch --depth 1 origin "$HF_REF"
  git -C "$HF_DIR" checkout "$HF_REF"
  git -C "$HF_DIR" pull --ff-only origin "$HF_REF" || true
else
  mkdir -p "$(dirname "$HF_DIR")"
  git clone --depth 1 --branch "$HF_REF" "$HF_REPO_URL" "$HF_DIR"
fi
ok "source ready"

args=()
case "$HF_PROFILE" in
  auto|"") ;;
  asus|generic) args+=(--profile "$HF_PROFILE") ;;
  *)
    echo "HF_PROFILE must be auto|asus|generic" >&2
    exit 2
    ;;
esac
[[ "$HF_YES" == "1" ]] && args+=(-y)
[[ "$HF_OPTIONAL" == "1" ]] && args+=(--with-optional)

info "running ./install.sh ${args[*]:-}"
cd "$HF_DIR"
chmod +x ./install.sh
./install.sh "${args[@]}"
ok "done — review snippets under modules/*/ and source HyprFluxStartup.conf"
