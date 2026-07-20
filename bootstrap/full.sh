#!/usr/bin/env bash
# HyprFlux full desktop bootstrap for a minimal Arch Linux install.
# Stages: packages -> JaKooLit base dots -> HyprFlux modules -> session wiring.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/ui.sh"
# shellcheck source=/dev/null
source "$repo_root/scripts/detect-vendor.sh"

ASSUME_YES="${HF_YES:-0}"
FORCE_PROFILE=""
INCLUDE_OPTIONAL=0

usage() {
  cat <<EOF
Usage: ./bootstrap/full.sh [options]

Options:
  --profile asus|generic|auto   Force hardware profile (default: auto)
  --with-optional               Include optional HyprFlux modules
  -y, --yes                     Skip confirmation prompts
  -h, --help                    Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

if [[ -n "$FORCE_PROFILE" ]]; then
  export HF_FORCE_PROFILE="$FORCE_PROFILE"
fi

if [[ "$(id -u)" -eq 0 ]]; then
  hf_err "Do not run the full bootstrap as root. Run as your normal user (sudo will prompt)."
  exit 1
fi

if [[ ! -f /etc/os-release ]] || ! grep -qi '^ID=arch' /etc/os-release; then
  hf_warn "This bootstrap targets Arch Linux. Continuing anyway, but package names may fail."
fi

hf_banner
hf_section "Machine"
vendor_line="$(hf_vendor_summary)"
profile="$(hf_detect_profile)"
hf_kv "Vendor" "$vendor_line"
hf_kv "Profile" "$profile"
hf_kv "Repo" "$repo_root"

hf_section "Plan"
hf_info "1) Install desktop packages (pacman + AUR)"
hf_info "2) Install JaKooLit Hyprland-Dots as the public base rice"
hf_info "3) Overlay HyprFlux modules for this machine profile"
hf_info "4) Wire session startup + enable login/audio services"
if [[ "$profile" == "asus" ]]; then
  hf_ok "ASUS extras will be included"
else
  hf_ok "Generic power stack will be used (ASUS packages skipped)"
fi

if [[ "$ASSUME_YES" != "1" ]]; then
  answer=""
  if ! hf_read_tty $'\n  Proceed with FULL desktop bootstrap into this user account? [y/N] ' answer; then
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

TTY_IN="${HF_TTY:-/dev/tty}"
[[ -r "$TTY_IN" ]] || TTY_IN="/dev/stdin"
export HF_TTY="$TTY_IN"

hf_section "Sudo"
hf_info "Administrator password may be required for package and service changes"
if [[ "$(id -u)" -ne 0 ]]; then
  sudo -v <"$TTY_IN"
fi

chmod +x \
  "$repo_root/bootstrap/"*.sh \
  "$repo_root/install.sh" \
  "$repo_root/scripts/"*.sh \
  "$repo_root/session/"*.sh

"$repo_root/bootstrap/install-packages.sh" "$profile"
"$repo_root/bootstrap/install-base-dots.sh"

hf_section "HyprFlux modules"
module_args=(-y)
[[ -n "$FORCE_PROFILE" ]] && module_args+=(--profile "$FORCE_PROFILE")
[[ "$INCLUDE_OPTIONAL" == "1" ]] && module_args+=(--with-optional)
"$repo_root/install.sh" "${module_args[@]}"

hf_section "Session wiring"
startup_file="$HOME/.config/hypr/UserConfigs/Startup_Apps.conf"
marker="HyprFluxStartup.conf"
if [[ -f "$startup_file" ]]; then
  if ! grep -Fq "$marker" "$startup_file"; then
    {
      printf '\n# HyprFlux session start (profile-aware)\n'
      printf 'source = $UserConfigs/HyprFluxStartup.conf\n'
    } >>"$startup_file"
    hf_ok "Appended HyprFlux startup source to Startup_Apps.conf"
  else
    hf_ok "Startup_Apps.conf already references HyprFlux"
  fi
else
  hf_warn "Startup_Apps.conf missing after dots install; HyprFluxStartup.conf is still in UserConfigs/"
fi

hf_section "Services"
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service pipewire.service >/dev/null 2>&1 || true
if systemctl list-unit-files sddm.service >/dev/null 2>&1; then
  sudo systemctl enable sddm.service <"$TTY_IN" || true
  hf_ok "SDDM enabled (reboot or start display manager to enter Hyprland)"
fi
if [[ "$profile" == "asus" ]]; then
  sudo systemctl enable --now asusd.service supergfxd.service <"$TTY_IN" 2>/dev/null || true
  sudo systemctl enable tlp.service <"$TTY_IN" 2>/dev/null || true
  # Prefer TLP over power-profiles-daemon when both exist on this stack.
  sudo systemctl disable --now power-profiles-daemon.service <"$TTY_IN" 2>/dev/null || true
  hf_ok "ASUS services enabled where available"
fi

hf_section "Done"
hf_ok "Full HyprFlux desktop bootstrap finished"
hf_info "Reboot, then log in through SDDM into Hyprland"
hf_info "First login runs JaKooLit initial-boot theming; HyprFlux modules are already overlaid"
hf_info "Optional: merge remaining snippet modules under modules/*/ (keybinds / Waybar polish)"
