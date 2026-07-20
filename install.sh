#!/usr/bin/env bash
# HyprFlux installer — pretty profile-aware module apply.
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

Options:
  --dry-run            Show actions without writing files
  --profile asus|generic|auto   Force profile (default: auto)
  --with-optional      Also install optional.modules
  -y, --yes            Non-interactive confirm
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
  hf_ok "ASUS stack enabled (asusctl / platform_profile / fan)"
  hf_info "generic-power-stack will not be installed"
else
  hf_ok "Generic power stack enabled"
  hf_warn "ASUS modules skipped on this machine"
fi
[[ "$INCLUDE_OPTIONAL" == "1" ]] && hf_info "optional: ${#OPTIONAL_MODULES[@]} modules"

hf_box_line "────────────────────────────────────────"
for m in "${MODULES[@]}"; do
  printf '  %s·%s %s\n' "$HF_CYAN" "$HF_RESET" "$m"
done
hf_box_line "────────────────────────────────────────"

if [[ "$ASSUME_YES" != "1" ]]; then
  printf '\n  Apply these modules into your home config? [y/N] '
  read -r answer
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
# Source this from Startup_Apps.conf:
#   source = \$UserConfigs/HyprFluxStartup.conf
exec-once = $startup_dest
EOF
  hf_ok "session start installed"
  hf_info "Add: source = \$UserConfigs/HyprFluxStartup.conf  to Startup_Apps.conf"
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
hf_info "Review snippets under modules/*/ for keybinds and Waybar merges"
hf_info "Run: ./scripts/check.sh"
