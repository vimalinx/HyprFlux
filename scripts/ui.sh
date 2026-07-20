#!/usr/bin/env bash
# HyprFlux 安装器 / 会话脚本共用的终端界面（中文）。

if [[ "${HYPRFLUX_UI_LOADED:-0}" == "1" ]]; then
  return 0 2>/dev/null || true
fi
HYPRFLUX_UI_LOADED=1

# 保证中文提示在大多数终端可正常显示
export LANG="${LANG:-zh_CN.UTF-8}"
export LC_ALL="${LC_ALL:-$LANG}"

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

# curl|bash 时 stdin 是脚本管道，交互必须走真实终端
HF_TTY="/dev/tty"
if [[ ! -r "$HF_TTY" || ! -w "$HF_TTY" ]]; then
  HF_TTY=""
fi

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
  │   ${HF_TEXT}Arch + Hyprland 桌面模块安装器${HF_CYAN}              │
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
  printf '  %s%-10s%s %s\n' "$HF_MUTED" "$1" "$HF_RESET$HF_TEXT" "$2$HF_RESET"
}

hf_box_line() {
  printf '  %s%s%s\n' "$HF_MUTED" "$1" "$HF_RESET"
}

# 从真实终端读入一行；避免 curl|bash 把确认直接吃成 EOF 退出
hf_read_tty() {
  local prompt="$1"
  local __outvar="$2"
  local __line=""
  if [[ -n "$HF_TTY" ]]; then
    printf '%s' "$prompt" >"$HF_TTY"
    if ! IFS= read -r __line <"$HF_TTY"; then
      __line=""
    fi
  elif [[ -t 0 ]]; then
    printf '%s' "$prompt"
    IFS= read -r __line || __line=""
  else
    hf_err "当前没有可用终端，无法交互确认。请改用：bash <(curl -fsSL https://arch.vimalinx.com/install)"
    hf_err "或设置 HF_YES=1 跳过确认。"
    return 1
  fi
  printf -v "$__outvar" '%s' "$__line"
}
