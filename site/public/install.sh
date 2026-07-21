#!/usr/bin/env bash
# HyprFlux one-line FULL desktop installer — https://arch.vimalinx.com/install
# Bare Arch -> packages + JaKooLit base dots + HyprFlux modules.
# China-friendly: auto-falls back to GitHub mirrors when github.com is unreachable.
set -euo pipefail

export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-$LANG}"

HF_REPO_URL="${HF_REPO_URL:-https://github.com/vimalinx/HyprFlux.git}"
HF_REF="${HF_REF:-main}"
HF_DIR="${HF_DIR:-$HOME/HyprFlux}"
HF_PROFILE="${HF_PROFILE:-auto}"
HF_YES="${HF_YES:-0}"
HF_OPTIONAL="${HF_OPTIONAL:-0}"
HF_CN="${HF_CN:-0}"
HF_GITHUB_MIRROR="${HF_GITHUB_MIRROR:-}"

BOLD=$'\033[1m'; RESET=$'\033[0m'
CYAN=$'\033[38;2;88;196;221m'
GREEN=$'\033[38;2;142;192;124m'
AMBER=$'\033[38;2;232;176;84m'
ROSE=$'\033[38;2;232;116;132m'
TEXT=$'\033[38;2;220;224;232m'

# curl|bash leaves stdin as the script pipe; interactive I/O must use a real TTY.
# -r/-w on /dev/tty can succeed even when open fails (ENXIO) with no controlling TTY —
# always probe with a real open, not test(1) mode bits.
HF_TTY=""
if { true </dev/tty; } 2>/dev/null && { true >/dev/tty; } 2>/dev/null; then
  HF_TTY="/dev/tty"
fi

hf_sudo_in() {
  if [[ -n "${HF_TTY:-}" ]] && { true <"$HF_TTY"; } 2>/dev/null; then
    printf '%s' "$HF_TTY"
  elif [[ -t 0 ]]; then
    printf '%s' "/dev/stdin"
  else
    printf '%s' "/dev/null"
  fi
}

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

curl_ok() {
  curl -fsSIL --connect-timeout 3 --max-time 6 -o /dev/null "$1" >/dev/null 2>&1
}

MIRROR_CANDIDATES=(
  "https://ghfast.top/https://github.com/"
  "https://gh-proxy.com/https://github.com/"
  "https://mirror.ghproxy.com/https://github.com/"
  "https://gitclone.com/github.com/"
)

mirror_url() {
  local url="$1" prefix="${2:-}"
  url="${url%.git}.git"
  if [[ -z "$prefix" ]]; then
    printf '%s\n' "$url"
    return 0
  fi
  printf '%s%s\n' "$prefix" "${url#https://github.com/}"
}

pick_mirror() {
  local cand
  if [[ -n "$HF_GITHUB_MIRROR" ]]; then
    printf '%s\n' "$HF_GITHUB_MIRROR"
    return 0
  fi
  if [[ "$HF_CN" != "1" ]] && curl_ok "https://github.com/"; then
    printf '\n'
    return 0
  fi
  for cand in "${MIRROR_CANDIDATES[@]}"; do
    if curl_ok "${cand%/https://github.com/}" || curl_ok "$cand"; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  printf '%s\n' "${MIRROR_CANDIDATES[0]}"
}

resolve_repo_url() {
  local url="$1" mirror
  # Only rewrite canonical github.com URLs.
  if [[ "$url" != https://github.com/* ]]; then
    printf '%s\n' "$url"
    return 0
  fi
  mirror="$(pick_mirror)"
  if [[ -z "$mirror" ]]; then
    printf '%s\n' "${url%.git}.git"
  else
    mirror_url "$url" "$mirror"
  fi
}

git_clone_github() {
  local url="$1" dest="$2"
  shift 2
  local resolved m cand tried=() skip t
  resolved="$(resolve_repo_url "$url")"
  info "clone: $resolved"
  tried+=("$resolved")
  if git clone "$@" "$resolved" "$dest"; then
    return 0
  fi
  for cand in "" "${MIRROR_CANDIDATES[@]}"; do
    if [[ -z "$cand" ]]; then
      m="${url%.git}.git"
    else
      m="$(mirror_url "$url" "$cand")"
    fi
    skip=0
    for t in "${tried[@]}"; do
      [[ "$t" == "$m" ]] && { skip=1; break; }
    done
    [[ "$skip" -eq 1 ]] && continue
    tried+=("$m")
    warn "Retry clone via $m"
    rm -f "$dest/.git/"*.lock 2>/dev/null || true
    rm -rf "$dest"
    if git clone "$@" "$m" "$dest"; then
      return 0
    fi
  done
  return 1
}

git_clone_fail_hint() {
  local msg="$1"
  if [[ "$msg" == *[Uu]nable\ to\ create* ]] || [[ "$msg" == *temporary\ file* ]]; then
    err "Disk or temp dir may be full — check free space:"
    df -h "${HF_DIR}" "$(dirname "$HF_DIR")" /tmp 2>/dev/null || df -h
  fi
}

HF_VENDOR_TAR="${HF_VENDOR_TAR:-https://arch.vimalinx.com/vendor/HyprFlux-main.tar.gz}"

sync_source_tarball() {
  local url="$HF_VENDOR_TAR" cache archive attempt expected actual remote_len local_len
  info "Trying vendor tarball: $url"
  if ! have curl; then
    warn "curl required for vendor tarball"
    return 1
  fi
  if ! have tar; then
    warn "tar required to extract vendor tarball"
    return 1
  fi
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/hyprflux"
  mkdir -p "$cache"
  archive="$cache/HyprFlux-main.tar.gz"

  expected="$(
    curl -fsSL --connect-timeout 10 --max-time 30 "${url}.sha256" 2>/dev/null \
      | awk 'NF>=1 {print $1; exit}'
  )"
  remote_len="$(
    curl -fsSIL --connect-timeout 10 --max-time 30 "$url" 2>/dev/null \
      | awk 'BEGIN{IGNORECASE=1} /^content-length:/ {print $2}' \
      | tr -d '\r' | tail -n1
  )"

  # Stale/partial cache from an older tarball revision will corrupt resume.
  if [[ -f "$archive" ]]; then
    local_len="$(wc -c <"$archive" | tr -d ' ')"
    if [[ -n "$remote_len" && "$local_len" -gt "$remote_len" ]]; then
      warn "Clearing oversized vendor cache (local=$local_len remote=$remote_len)"
      rm -f "$archive"
    fi
  fi

  for attempt in 1 2 3 4 5; do
    info "Vendor tarball download attempt $attempt/5 (resumable)"
    if curl -fL --connect-timeout 15 --max-time 900 \
         --retry 0 -C - \
         -o "$archive" "$url"; then
      :
    else
      warn "Vendor tarball attempt $attempt incomplete — will resume"
      sleep 2
      [[ "$attempt" -eq 5 ]] && { warn "Vendor tarball download failed after resumes"; return 1; }
      continue
    fi

    if [[ -n "$expected" ]]; then
      actual="$(sha256sum "$archive" | awk '{print $1}')"
      if [[ "$actual" != "$expected" ]]; then
        warn "Vendor tarball checksum mismatch — clearing cache and retrying"
        rm -f "$archive"
        sleep 1
        continue
      fi
      ok "Vendor tarball checksum OK"
    fi

    mkdir -p "$(dirname "$HF_DIR")"
    rm -rf "$HF_DIR"
    mkdir -p "$HF_DIR"
    if tar -xzf "$archive" -C "$HF_DIR"; then
      if [[ -f "$HF_DIR/bootstrap/full.sh" ]]; then
        ok "Source synced from vendor tarball"
        return 0
      fi
      warn "Vendor tarball missing bootstrap/full.sh"
    else
      warn "Vendor tarball extract failed (corrupt download cleared)"
    fi
    rm -rf "$HF_DIR"
    rm -f "$archive"
    sleep 1
  done
  warn "Vendor tarball download failed after resumes"
  return 1
}

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
  if sudo -n true 2>/dev/null; then
    return 0
  fi
  local sin
  sin="$(hf_sudo_in)"
  if [[ "$sin" == "/dev/null" ]]; then
    err "sudo needs a password but no controlling TTY is available"
    err "Authenticate first (sudo -v), or run under SSH -tt / a real terminal."
    exit 1
  fi
  info "Administrator (sudo) password may be required"
  sudo -v <"$sin" || { err "sudo authentication failed"; exit 1; }
}

pkg_install() {
  local pkgs=("$@") mgr sin
  mgr="$(detect_pkg)"
  ensure_sudo
  sin="$(hf_sudo_in)"
  info "Installing: ${pkgs[*]} via $mgr"
  case "$mgr" in
    pacman) sudo pacman -Sy --needed --noconfirm "${pkgs[@]}" <"$sin" ;;
    apt)
      sudo apt-get update <"$sin"
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}" <"$sin"
      ;;
    dnf) sudo dnf install -y "${pkgs[@]}" <"$sin" ;;
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

sync_source() {
  local fetch_url clone_log prefer_tarball=0

  if [[ "$HF_CN" == "1" ]] || ! curl_ok "https://github.com/"; then
    prefer_tarball=1
  fi

  if [[ "$prefer_tarball" -eq 1 ]]; then
    if sync_source_tarball; then
      chmod +x "$HF_DIR/bootstrap/full.sh"
      return 0
    fi
    warn "Vendor tarball unavailable — falling back to git clone"
  fi

  fetch_url="$(resolve_repo_url "$HF_REPO_URL")"
  if [[ "$fetch_url" != "$HF_REPO_URL" && "$fetch_url" != "${HF_REPO_URL%.git}.git" ]]; then
    warn "GitHub looks blocked/slow — using mirror: $fetch_url"
  fi

  if [[ -d "$HF_DIR/.git" ]]; then
    info "Existing checkout found — resetting to $HF_REF"
    rm -f "$HF_DIR/.git/"*.lock 2>/dev/null || true
    git -C "$HF_DIR" remote set-url origin "$fetch_url" >/dev/null 2>&1 || true
    if ! git -C "$HF_DIR" fetch --depth 1 origin "$HF_REF"; then
      warn "Fetch failed — recloning cleanly"
      rm -f "$HF_DIR/.git/"*.lock 2>/dev/null || true
      rm -rf "$HF_DIR"
    fi
  fi

  if [[ ! -d "$HF_DIR/.git" ]]; then
    mkdir -p "$(dirname "$HF_DIR")"
    rm -f "$HF_DIR/.git/"*.lock 2>/dev/null || true
    rm -rf "$HF_DIR"
    clone_log="$(mktemp)"
    if ! git_clone_github "$HF_REPO_URL" "$HF_DIR" --depth 1 --branch "$HF_REF" 2>"$clone_log"; then
      [[ -s "$clone_log" ]] && cat "$clone_log" >&2
      git_clone_fail_hint "$(<"$clone_log")"
      rm -f "$clone_log"
      err "Failed to clone HyprFlux (tried GitHub + China mirrors)"
      err "Set HF_GITHUB_MIRROR explicitly, e.g. HF_CN=1 or HF_GITHUB_MIRROR=https://ghfast.top/https://github.com/"
      exit 1
    fi
    rm -f "$clone_log"
    # Keep origin pointed at a working remote for later updates.
    git -C "$HF_DIR" remote set-url origin "$(resolve_repo_url "$HF_REPO_URL")" || true
  else
    git -C "$HF_DIR" checkout -B "$HF_REF" "FETCH_HEAD" 2>/dev/null \
      || git -C "$HF_DIR" checkout -B "$HF_REF" "origin/$HF_REF"
    git -C "$HF_DIR" reset --hard "origin/$HF_REF" 2>/dev/null \
      || git -C "$HF_DIR" reset --hard "FETCH_HEAD"
    git -C "$HF_DIR" clean -fd
  fi

  if [[ ! -f "$HF_DIR/bootstrap/full.sh" ]]; then
    err "bootstrap/full.sh missing after sync — refusing to continue"
    err "Delete $HF_DIR and rerun, or check network/mirrors"
    exit 1
  fi
  chmod +x "$HF_DIR/bootstrap/full.sh"
}

banner
info "This installs a FULL Arch Hyprland desktop (packages + JaKooLit dots + HyprFlux)."
info "Checking bootstrap dependencies…"
ensure_cmd git git
if ! have curl && ! have wget; then
  ensure_cmd curl curl
fi
ok "Dependencies ready"

if [[ "$HF_CN" == "1" ]]; then
  info "HF_CN=1 — preferring vendor tarball, then China GitHub mirrors"
elif ! curl_ok "https://github.com/"; then
  warn "github.com unreachable — will try vendor tarball, then China GitHub mirrors"
fi

info "repo: $HF_REPO_URL ($HF_REF)"
info "target: $HF_DIR"
sync_source
if [[ -d "$HF_DIR/.git" ]]; then
  ok "Source ready ($(git -C "$HF_DIR" rev-parse --short HEAD))"
else
  ok "Source ready (vendor tarball)"
fi

# Export mirror prefs for nested bootstrap scripts.
export HF_CN HF_GITHUB_MIRROR
export HF_REPO_URL

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
chmod +x ./bootstrap/*.sh ./install.sh ./scripts/*.sh ./session/*.sh 2>/dev/null || true
./bootstrap/full.sh "${args[@]}"
ok "Full desktop bootstrap finished — reboot and log into Hyprland"

# Vendor tarball: regenerate with ./scripts/build-vendor-tarball.sh then deploy site/public.
# vendor-tarball-sha256 2026-07-21T08:10:00+08:00
