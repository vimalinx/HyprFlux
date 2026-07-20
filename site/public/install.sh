#!/usr/bin/env bash
# HyprFlux one-line installer — https://arch.vimalinx.com/install
# Missing tools (git, etc.) are installed automatically via sudo.
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
ROSE=$'\033[38;2;232;116;132m'
TEXT=$'\033[38;2;220;224;232m'

# curl|bash often has no TTY on stdin; prefer /dev/tty for prompts.
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
  │   HyprFlux · one-line installer              │
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
  if have pacman; then
    printf 'pacman\n'
  elif have apt-get; then
    printf 'apt\n'
  elif have dnf; then
    printf 'dnf\n'
  elif have zypper; then
    printf 'zypper\n'
  else
    printf 'unknown\n'
  fi
}

ensure_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then
    return 0
  fi
  if ! have sudo; then
    err "需要 sudo 才能自动安装缺失软件包，但系统里没有 sudo"
    exit 1
  fi
  info "接下来可能需要输入管理员（sudo）密码"
  # Refresh credentials using the real terminal, not the curl pipe.
  if ! sudo -v <"$TTY_IN"; then
    err "sudo 认证失败"
    exit 1
  fi
}

pkg_install() {
  local pkgs=("$@")
  local mgr
  mgr="$(detect_pkg)"
  ensure_sudo
  info "安装缺失依赖: ${pkgs[*]} （包管理器: $mgr）"
  case "$mgr" in
    pacman)
      sudo pacman -Sy --needed --noconfirm "${pkgs[@]}" <"$TTY_IN"
      ;;
    apt)
      sudo apt-get update <"$TTY_IN"
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}" <"$TTY_IN"
      ;;
    dnf)
      sudo dnf install -y "${pkgs[@]}" <"$TTY_IN"
      ;;
    zypper)
      sudo zypper --non-interactive install "${pkgs[@]}" <"$TTY_IN"
      ;;
    *)
      err "无法识别包管理器，请手动安装: ${pkgs[*]}"
      exit 1
      ;;
  esac
}

ensure_cmd() {
  local cmd="$1"
  local pkg="${2:-$1}"
  if have "$cmd"; then
    ok "$cmd 已就绪"
    return 0
  fi
  warn "缺少 $cmd — 准备自动安装 $pkg"
  pkg_install "$pkg"
  if ! have "$cmd"; then
    err "安装后仍找不到命令: $cmd"
    exit 1
  fi
  ok "$cmd 安装完成"
}

banner
info "检测依赖…"

# bash is required to run this script already; still ensure core tools.
ensure_cmd git git
# curl is usually present (you fetched this script with it), but keep it healthy.
if ! have curl && ! have wget; then
  ensure_cmd curl curl
fi

ok "依赖就绪"
info "repo: $HF_REPO_URL ($HF_REF)"
info "target: $HF_DIR"

if [[ -d "$HF_DIR/.git" ]]; then
  info "已有仓库 — 拉取 $HF_REF"
  git -C "$HF_DIR" fetch --depth 1 origin "$HF_REF"
  git -C "$HF_DIR" checkout "$HF_REF"
  git -C "$HF_DIR" pull --ff-only origin "$HF_REF" || true
else
  mkdir -p "$(dirname "$HF_DIR")"
  git clone --depth 1 --branch "$HF_REF" "$HF_REPO_URL" "$HF_DIR"
fi
ok "源码就绪"

args=()
case "$HF_PROFILE" in
  auto|"") ;;
  asus|generic) args+=(--profile "$HF_PROFILE") ;;
  *)
    err "HF_PROFILE 只能是 auto|asus|generic"
    exit 2
    ;;
esac
[[ "$HF_YES" == "1" ]] && args+=(-y)
[[ "$HF_OPTIONAL" == "1" ]] && args+=(--with-optional)

info "运行 ./install.sh ${args[*]:-}"
cd "$HF_DIR"
chmod +x ./install.sh
./install.sh "${args[@]}"
ok "完成 — 请按模块 README 合并快捷键/Waybar，并 source HyprFluxStartup.conf"
