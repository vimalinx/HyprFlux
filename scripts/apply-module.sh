#!/usr/bin/env bash
# Apply one HyprFlux module using an optional DEST map.
# DEST lines: source|destination|mode
# destination may start with ~/ and is expanded.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/ui.sh"

module_name="${1:-}"
dry_run="${HF_DRY_RUN:-0}"

if [[ -z "$module_name" ]]; then
  echo "usage: $0 <module-name>" >&2
  exit 2
fi

module_dir="$repo_root/modules/$module_name"
if [[ ! -d "$module_dir" ]]; then
  hf_err "unknown module: $module_name"
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
      hf_info "backup $dest -> $bak"
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
    hf_warn "missing source in $module_name: $src_rel"
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
    hf_info "would run $module_name/apply.sh"
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

hf_warn "$module_name has no DEST or apply.sh (docs-only / snippet module)"
