#!/usr/bin/env bash
# HyprFlux one-line FULL desktop installer — https://arch.vimalinx.com/install
# Bare Arch -> packages + JaKooLit base dots + HyprFlux modules.
set -euo pipefail

export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-$LANG}"

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
ROSE=$'\033[38;2;232;116;132m'
TEXT=$'\033[38;2;220;224;232m'

TTY_IN="/dev/tty"
if [[ ! -r "$TTY_IN" ]]; then
  TTY_IN="/dev/stdin"
fi

if [[ ! -t 1 || -n "${NO_COLOR:-}" ]]; then
  BOLD=""; RESET=""; CYAN=""; GREEN=""; AMBER=""; ROSE=""; TEXT=""
fi

banner() {
  cat <<BANNER
${CYAN}${BOLD}
  ┌──────────────────────────────────────────────┐
  │   HyprFlux · full desktop installer          │
  │   ${TEXT}arch.vimalinx.com${CYAN}                          │
  └──────────────────────────────────────────────┘
${RESET}
BANNER
}

info() { printf '  %s•%s %s\n' "$CYAN" "$RESET" "$1"; }
ok() { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
warn() { printf '  %s!%s %s\n' "$AMBER" "$RESET" "$1"; }
err() { printf '  %s✗%s %s\n' "$ROSE" "$RESET" "$1" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

detect_pkg() {
  if have pacman; then printf 'pacman\n'
  elif have apt-get; then printf 'apt\n'
  elif have dnf; then printf 'dnf\n'
  else printf 'unknown\n'
  fi
}

ensure_sudo() {
  [[ "$(id -u)" -eq 0 ]] && return 0
  if ! have sudo; then
    err "sudo is required to install missing packages"
    exit 1
  fi
  info "Administrator (sudo) password may be required"
  sudo -v <"$TTY_IN" || { err "sudo authentication failed"; exit 1; }
}

pkg_install() {
  local pkgs=("$@") mgr
  mgr="$(detect_pkg)"
  ensure_sudo
  info "Installing: ${pkgs[*]} via $mgr"
  case "$mgr" in
    pacman) sudo pacman -Sy --needed --noconfirm "${pkgs[@]}" <"$TTY_IN" ;;
    apt)
      sudo apt-get update <"$TTY_IN"
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}" <"$TTY_IN"
      ;;
    dnf) sudo dnf install -y "${pkgs[@]}" <"$TTY_IN" ;;
    *) err "Unsupported package manager; install manually: ${pkgs[*]}"; exit 1 ;;
  esac
}

ensure_cmd() {
  local cmd="$1" pkg="${2:-$1}"
  if have "$cmd"; then
    ok "$cmd ready"
    return 0
  fi
  warn "Missing $cmd — installing $pkg"
  pkg_install "$pkg"
  have "$cmd" || { err "Still missing after install: $cmd"; exit 1; }
  ok "$cmd installed"
}

banner
info "This installs a FULL Arch Hyprland desktop (packages + JaKooLit dots + HyprFlux)."
info "Checking bootstrap dependencies…"
ensure_cmd git git
if ! have curl && ! have wget; then
  ensure_cmd curl curl
fi
ok "Dependencies ready"

info "repo: $HF_REPO_URL ($HF_REF)"
info "target: $HF_DIR"

if [[ -d "$HF_DIR/.git" ]]; then
  info "Existing checkout found — updating $HF_REF"
  git -C "$HF_DIR" fetch --depth 1 origin "$HF_REF"
  git -C "$HF_DIR" checkout "$HF_REF"
  git -C "$HF_DIR" pull --ff-only origin "$HF_REF" || true
else
  mkdir -p "$(dirname "$HF_DIR")"
  git clone --depth 1 --branch "$HF_REF" "$HF_REPO_URL" "$HF_DIR"
fi
ok "Source ready"

args=()
case "$HF_PROFILE" in
  auto|"") ;;
  asus|generic) args+=(--profile "$HF_PROFILE") ;;
  *) err "HF_PROFILE must be auto|asus|generic"; exit 2 ;;
esac
[[ "$HF_YES" == "1" ]] && args+=(-y)
[[ "$HF_OPTIONAL" == "1" ]] && args+=(--with-optional)

info "Starting full bootstrap…"
cd "$HF_DIR"
chmod +x ./bootstrap/full.sh
./bootstrap/full.sh "${args[@]}"
ok "Full desktop bootstrap finished — reboot and log into Hyprland"
