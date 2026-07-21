#!/usr/bin/env bash
# HyprFlux module installer (English). Prefer bootstrap/full.sh on a bare Arch system.
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
Usage: ./install.sh [options]

Apply HyprFlux modules into the current user's home config.
For a bare Arch machine, use ./bootstrap/full.sh instead (also what arch.vimalinx.com runs).

Options:
  --dry-run            Show the plan without writing files
  --profile asus|generic|auto   Force profile (default: auto)
  --with-optional      Include optional modules
  -y, --yes            Skip confirmation
  -h, --help           Show this help
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
      hf_err "unknown argument: $1"
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
hf_section "Machine"
vendor_line="$(hf_vendor_summary)"
profile="$(hf_detect_profile)"
hf_kv "Vendor" "$vendor_line"
hf_kv "Profile" "$profile"
hf_kv "Repo" "$repo_root"
[[ "$DRY_RUN" == "1" ]] && hf_warn "Dry-run mode: no files will be written"

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

hf_section "Plan"
hf_info "common: ${#COMMON_MODULES[@]} modules"
hf_info "$profile: ${#PROFILE_MODULES[@]} modules"
if [[ "$profile" == "asus" ]]; then
  hf_ok "ASUS power/fan stack enabled"
  hf_info "generic-power-stack will not be installed"
else
  hf_ok "Generic power stack enabled"
  hf_warn "ASUS-only modules will be skipped"
fi
[[ "$INCLUDE_OPTIONAL" == "1" ]] && hf_info "optional: ${#OPTIONAL_MODULES[@]} modules"

hf_box_line "────────────────────────────────────────"
for m in "${MODULES[@]}"; do
  printf '  %s·%s %s\n' "$HF_CYAN" "$HF_RESET" "$m"
done
hf_box_line "────────────────────────────────────────"

if [[ "$ASSUME_YES" != "1" ]]; then
  answer=""
  if ! hf_read_tty $'\n  Apply these modules into your home config? [y/N] ' answer; then
    exit 1
  fi
  case "$answer" in
    y|Y|yes|YES) ;;
    *)
      hf_warn "Aborted"
      exit 1
      ;;
  esac
fi

hf_section "Apply"
total="${#MODULES[@]}"
idx=0
failed=0
for m in "${MODULES[@]}"; do
  idx=$((idx + 1))
  hf_step "$idx" "$total" "$m"
  if ! "$repo_root/scripts/apply-module.sh" "$m"; then
    hf_err "failed: $m"
    failed=$((failed + 1))
  fi
done

verify_module_outputs() {
  local missing=0
  local mod src_rel dest_spec dest expanded
  for mod in "${MODULES[@]}"; do
    local dest_file="$repo_root/modules/$mod/DEST"
    [[ -f "$dest_file" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" == \#* ]] && continue
      IFS='|' read -r src_rel dest_spec _mode <<<"$line"
      if [[ "${dest_spec:0:2}" == "~/" ]]; then
        expanded="$HOME/${dest_spec#~/}"
      elif [[ "$dest_spec" == "~" ]]; then
        expanded="$HOME"
      else
        expanded="$dest_spec"
      fi
      if [[ ! -e "$expanded" ]]; then
        hf_err "missing after apply: $mod -> $expanded"
        missing=$((missing + 1))
      fi
    done <"$dest_file"
  done
  if ((missing > 0)); then
    hf_err "$missing expected module file(s) missing under \$HOME (check expand_dest / DEST paths)"
    return 1
  fi
  hf_ok "module DEST outputs verified"
  return 0
}

if [[ "$DRY_RUN" != "1" ]]; then
  verify_module_outputs || failed=$((failed + 1))
fi

hf_section "Session startup"
startup_src="$repo_root/session/hyprflux-session-start.sh"
startup_dest="$HOME/.config/hypr/UserScripts/hyprflux-session-start.sh"
snippet_dest="$HOME/.config/hypr/UserConfigs/HyprFluxStartup.conf"
if [[ "$DRY_RUN" == "1" ]]; then
  hf_info "would install $startup_dest"
  hf_info "would install $snippet_dest"
else
  mkdir -p "$(dirname "$startup_dest")" "$(dirname "$snippet_dest")"
  cp -a "$startup_src" "$startup_dest"
  chmod 755 "$startup_dest"
  cat >"$snippet_dest" <<EOF
# HyprFlux session start — profile-aware (ASUS vs generic).
# Sourced from Startup_Apps.conf by the full bootstrap:
#   source = \$UserConfigs/HyprFluxStartup.conf
exec-once = $startup_dest
EOF
  hf_ok "session start installed"
fi

if command -v systemctl >/dev/null 2>&1 && [[ "$DRY_RUN" != "1" ]]; then
  systemctl --user daemon-reload || true
fi

hf_section "Done"
if ((failed > 0)); then
  hf_err "$failed module(s) failed"
  exit 1
fi
hf_ok "HyprFlux $profile profile applied"
hf_info "Review snippet-only modules under modules/*/ when you want extra polish"
hf_info "Self-check: ./scripts/check.sh"
