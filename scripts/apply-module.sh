#!/usr/bin/env bash
# 应用单个 HyprFlux 模块（读取可选 DEST 映射）。
# DEST 行格式: 源相对路径|目标路径|权限
# 目标路径可用 ~/ 开头。

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/ui.sh"

module_name="${1:-}"
dry_run="${HF_DRY_RUN:-0}"

if [[ -z "$module_name" ]]; then
  echo "用法: $0 <模块名>" >&2
  exit 2
fi

module_dir="$repo_root/modules/$module_name"
if [[ ! -d "$module_dir" ]]; then
  hf_err "未知模块: $module_name"
  exit 1
fi

expand_dest() {
  local dest="$1"
  if [[ "$dest" == ~/* ]]; then
    printf '%s\n' "$HOME/${dest#~/}"
  else
    printf '%s\n' "$dest"
  fi
}

backup_if_needed() {
  local dest="$1"
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    local bak="${dest}.hyprflux-bak.$(date +%Y%m%d-%H%M%S)"
    if [[ "$dry_run" == "1" ]]; then
      hf_info "将备份 $dest -> $bak"
    else
      cp -a "$dest" "$bak"
    fi
  fi
}

apply_dest_line() {
  local src_rel="$1" dest_spec="$2" mode="${3:-644}"
  local src="$module_dir/$src_rel"
  local dest
  dest="$(expand_dest "$dest_spec")"

  if [[ ! -e "$src" ]]; then
    hf_warn "$module_name 缺少源文件: $src_rel"
    return 0
  fi

  if [[ "$dry_run" == "1" ]]; then
    hf_info "$module_name: $src_rel -> $dest ($mode)"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  backup_if_needed "$dest"
  cp -a "$src" "$dest"
  chmod "$mode" "$dest" 2>/dev/null || true
}

if [[ -x "$module_dir/apply.sh" ]]; then
  if [[ "$dry_run" == "1" ]]; then
    hf_info "将执行 $module_name/apply.sh"
  else
    "$module_dir/apply.sh"
  fi
  exit 0
fi

if [[ -f "$module_dir/DEST" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    IFS='|' read -r src_rel dest_spec mode <<<"$line"
    apply_dest_line "$src_rel" "$dest_spec" "${mode:-644}"
  done <"$module_dir/DEST"
  exit 0
fi

hf_warn "$module_name 没有 DEST / apply.sh（仅文档或片段，需手动合并）"
