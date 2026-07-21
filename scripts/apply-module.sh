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
  if [[ "${dest:0:2}" == "~/" ]]; then
    printf '%s\n' "$HOME/${dest:2}"
  elif [[ "$dest" == "~" ]]; then
    printf '%s\n' "$HOME"
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
    return 1
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

write_applied_marker() {
  local marker_dir="$HOME/.config/hypr/.hyprflux-modules"
  local marker="$marker_dir/${module_name}.applied"
  if [[ "$dry_run" == "1" ]]; then
    hf_info "would write marker $marker"
    return 0
  fi
  mkdir -p "$marker_dir"
  {
    printf 'module=%s\n' "$module_name"
    printf 'applied_at=%s\n' "$(date -Is)"
    printf 'repo=%s\n' "$repo_root"
  } >"$marker"
}

merge_waybar_snippets() {
  local merge_py="$repo_root/scripts/merge-waybar-user-modules.py"
  local -a snippets=()
  local candidate

  if [[ -f "$module_dir/waybar-module.jsonc" ]]; then
    snippets+=("$module_dir/waybar-module.jsonc")
  fi
  while IFS= read -r -d '' candidate; do
    snippets+=("$candidate")
  done < <(find "$module_dir/waybar" -maxdepth 1 -name '*.jsonc' -print0 2>/dev/null || true)

  ((${#snippets[@]} == 0)) && return 0
  if [[ ! -x "$merge_py" && ! -f "$merge_py" ]]; then
    hf_warn "$module_name: merge script missing ($merge_py)"
    return 1
  fi
  if [[ "$dry_run" == "1" ]]; then
    hf_info "would merge waybar snippets for $module_name (${#snippets[@]} file(s))"
    return 0
  fi
  python3 "$merge_py" "${snippets[@]}"
}

if [[ -x "$module_dir/apply.sh" ]]; then
  if [[ "$dry_run" == "1" ]]; then
    hf_info "would run $module_name/apply.sh"
    merge_waybar_snippets || true
  else
    "$module_dir/apply.sh"
    merge_waybar_snippets || hf_warn "$module_name: waybar UserModules merge skipped/failed"
    write_applied_marker
  fi
  exit 0
fi

if [[ -f "$module_dir/DEST" ]]; then
  errors=0
  copied=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    IFS='|' read -r src_rel dest_spec mode <<<"$line"
    if apply_dest_line "$src_rel" "$dest_spec" "${mode:-644}"; then
      copied=$((copied + 1))
    else
      errors=$((errors + 1))
    fi
  done <"$module_dir/DEST"
  if ((errors > 0)); then
    hf_err "$module_name: $errors missing source file(s)"
    exit 1
  fi
  merge_waybar_snippets || hf_warn "$module_name: waybar UserModules merge skipped/failed"
  if ((copied > 0)); then
    write_applied_marker
  fi
  exit 0
fi

if [[ -f "$module_dir/waybar-module.jsonc" ]] || [[ -d "$module_dir/waybar" ]]; then
  if [[ "$dry_run" == "1" ]]; then
    merge_waybar_snippets || true
  else
    merge_waybar_snippets || hf_warn "$module_name: waybar UserModules merge skipped/failed"
    write_applied_marker
  fi
  exit 0
fi

hf_info "$module_name: docs-only (no DEST or apply.sh — merge snippets manually)"
exit 0
