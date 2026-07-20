#!/usr/bin/env bash
# HyprFlux 安装器：按华硕 / 通用配置文件应用桌面模块。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/ui.sh"
# shellcheck source=/dev/null
source "$repo_root/scripts/detect-vendor.sh"

DRY_RUN=0
INCLUDE_OPTIONAL=0
FORCE_PROFILE=""
ASSUME_YES=0

usage() {
  cat <<EOF
用法: ./install.sh [选项]

选项:
  --dry-run            只显示计划，不写入文件
  --profile asus|generic|auto   强制配置档（默认 auto）
  --with-optional      同时安装可选模块
  -y, --yes            跳过确认，直接安装
  -h, --help           显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --profile)
      FORCE_PROFILE="${2:-}"
      shift 2
      ;;
    --with-optional) INCLUDE_OPTIONAL=1; shift ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      hf_err "未知参数: $1"
      usage
      exit 2
      ;;
  esac
done

export HF_DRY_RUN="$DRY_RUN"
if [[ -n "$FORCE_PROFILE" ]]; then
  export HF_FORCE_PROFILE="$FORCE_PROFILE"
fi

hf_banner
hf_section "机器信息"
vendor_line="$(hf_vendor_summary)"
profile="$(hf_detect_profile)"
profile_label="$profile"
case "$profile" in
  asus) profile_label="华硕 (asus)" ;;
  generic) profile_label="通用 (generic)" ;;
esac
hf_kv "厂商" "$vendor_line"
hf_kv "配置档" "$profile_label"
hf_kv "仓库" "$repo_root"
[[ "$DRY_RUN" == "1" ]] && hf_warn "演练模式：不会写入任何文件"

read_modules() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    printf '%s\n' "$line"
  done <"$file"
}

mapfile -t COMMON_MODULES < <(read_modules "$repo_root/profiles/common.modules")
mapfile -t PROFILE_MODULES < <(read_modules "$repo_root/profiles/${profile}.modules")
OPTIONAL_MODULES=()
if [[ "$INCLUDE_OPTIONAL" == "1" ]]; then
  mapfile -t OPTIONAL_MODULES < <(read_modules "$repo_root/profiles/optional.modules")
fi

MODULES=("${COMMON_MODULES[@]}" "${PROFILE_MODULES[@]}" "${OPTIONAL_MODULES[@]}")

hf_section "安装计划"
hf_info "通用模块: ${#COMMON_MODULES[@]} 个"
hf_info "${profile_label} 模块: ${#PROFILE_MODULES[@]} 个"
if [[ "$profile" == "asus" ]]; then
  hf_ok "已启用华硕电源 / 风扇栈"
  hf_info "不会安装通用电源栈 (generic-power-stack)"
else
  hf_ok "已启用通用电源栈"
  hf_warn "本机将跳过华硕专用模块"
fi
[[ "$INCLUDE_OPTIONAL" == "1" ]] && hf_info "可选模块: ${#OPTIONAL_MODULES[@]} 个"

hf_box_line "────────────────────────────────────────"
for m in "${MODULES[@]}"; do
  printf '  %s·%s %s\n' "$HF_CYAN" "$HF_RESET" "$m"
done
hf_box_line "────────────────────────────────────────"

if [[ "$ASSUME_YES" != "1" ]]; then
  answer=""
  if ! hf_read_tty $'\n  要把这些模块写入你的家目录配置吗？[y/N] ' answer; then
    exit 1
  fi
  case "$answer" in
    y|Y|yes|YES|是|好|安装|确认)
      ;;
    *)
      hf_warn "已取消安装"
      exit 1
      ;;
  esac
fi

hf_section "正在应用"
total="${#MODULES[@]}"
idx=0
failed=0
for m in "${MODULES[@]}"; do
  idx=$((idx + 1))
  hf_step "$idx" "$total" "$m"
  if ! "$repo_root/scripts/apply-module.sh" "$m"; then
    hf_err "失败: $m"
    failed=$((failed + 1))
  fi
done

hf_section "会话启动"
startup_src="$repo_root/session/hyprflux-session-start.sh"
startup_dest="$HOME/.config/hypr/UserScripts/hyprflux-session-start.sh"
snippet_dest="$HOME/.config/hypr/UserConfigs/HyprFluxStartup.conf"
if [[ "$DRY_RUN" == "1" ]]; then
  hf_info "将安装 $startup_dest"
  hf_info "将安装 $snippet_dest"
else
  mkdir -p "$(dirname "$startup_dest")" "$(dirname "$snippet_dest")"
  cp -a "$startup_src" "$startup_dest"
  chmod 755 "$startup_dest"
  cat >"$snippet_dest" <<EOF
# HyprFlux 会话启动（按华硕 / 通用配置档分流）
# 请在 Startup_Apps.conf 中加入：
#   source = \$UserConfigs/HyprFluxStartup.conf
exec-once = $startup_dest
EOF
  hf_ok "会话启动脚本已安装"
  hf_info "请在 Startup_Apps.conf 加入: source = \$UserConfigs/HyprFluxStartup.conf"
fi

if command -v systemctl >/dev/null 2>&1 && [[ "$DRY_RUN" != "1" ]]; then
  systemctl --user daemon-reload || true
fi

hf_section "完成"
if ((failed > 0)); then
  hf_err "有 $failed 个模块失败"
  exit 1
fi
hf_ok "已应用 HyprFlux「${profile_label}」配置档"
hf_info "请按 modules/*/README.md 合并快捷键与 Waybar 片段"
hf_info "自检命令: ./scripts/check.sh"
