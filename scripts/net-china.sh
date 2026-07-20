#!/usr/bin/env bash
# GitHub / AUR reachability helpers for China-friendly bootstrap.
# Safe for public repos only — never send credentials through third-party mirrors.

if [[ "${HYPRFLUX_NET_LOADED:-0}" == "1" ]]; then
  return 0 2>/dev/null || true
fi
HYPRFLUX_NET_LOADED=1

# Optional force: HF_CN=1 or HF_GITHUB_MIRROR=https://ghfast.top/https://github.com/
HF_CN="${HF_CN:-0}"
HF_GITHUB_MIRROR="${HF_GITHUB_MIRROR:-}"

# Prefix mirrors that expect: ${prefix}https://github.com/owner/repo.git
# OR bare-host mirrors that expect: ${prefix}owner/repo.git  (set kind=path)
HF_GITHUB_MIRROR_CANDIDATES=(
  "https://ghfast.top/https://github.com/"
  "https://gh-proxy.com/https://github.com/"
  "https://mirror.ghproxy.com/https://github.com/"
  "https://gitclone.com/github.com/"
)

hf_curl_ok() {
  local url="$1"
  curl -fsSIL --connect-timeout 3 --max-time 6 -o /dev/null "$url" >/dev/null 2>&1
}

hf_github_direct_ok() {
  [[ "${HF_CN}" == "1" ]] && return 1
  hf_curl_ok "https://github.com/"
}

hf_normalize_github_url() {
  local url="$1"
  url="${url%.git}.git"
  printf '%s\n' "$url"
}

# Convert https://github.com/owner/repo.git -> mirrored URL
hf_mirror_github_url() {
  local url prefix
  url="$(hf_normalize_github_url "$1")"
  prefix="${2:-}"
  if [[ -z "$prefix" ]]; then
    printf '%s\n' "$url"
    return 0
  fi
  if [[ "$prefix" == *"/https://github.com/" ]]; then
    printf '%s%s\n' "$prefix" "${url#https://github.com/}"
  elif [[ "$prefix" == *"/github.com/" ]]; then
    printf '%s%s\n' "$prefix" "${url#https://github.com/}"
  else
    printf '%s%s\n' "$prefix" "$url"
  fi
}

hf_pick_github_mirror() {
  local cand
  if [[ -n "$HF_GITHUB_MIRROR" ]]; then
    printf '%s\n' "$HF_GITHUB_MIRROR"
    return 0
  fi
  if hf_github_direct_ok; then
    printf '\n'
    return 0
  fi
  for cand in "${HF_GITHUB_MIRROR_CANDIDATES[@]}"; do
    # Probe the mirror origin host only
    if hf_curl_ok "${cand%%/https://github.com/*}" || hf_curl_ok "${cand}"; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  # Last resort: still return first candidate and let git fail loudly.
  printf '%s\n' "${HF_GITHUB_MIRROR_CANDIDATES[0]}"
}

# Resolve a github.com URL for the current network.
hf_resolve_github_url() {
  local url mirror
  url="$(hf_normalize_github_url "$1")"
  mirror="$(hf_pick_github_mirror)"
  if [[ -z "$mirror" ]]; then
    printf '%s\n' "$url"
  else
    hf_mirror_github_url "$url" "$mirror"
  fi
}

# Clone with automatic GitHub mirror fallback.
# Usage: hf_git_clone_github https://github.com/owner/repo.git /dest [extra git clone args...]
hf_git_clone_github() {
  local url="$1"
  local dest="$2"
  shift 2
  local resolved mirrors tried=()
  local m cand

  resolved="$(hf_resolve_github_url "$url")"
  tried+=("$resolved")
  if git clone "$@" "$resolved" "$dest"; then
    return 0
  fi

  # If direct or chosen mirror failed, walk the candidate list.
  for cand in "" "${HF_GITHUB_MIRROR_CANDIDATES[@]}"; do
    if [[ -z "$cand" ]]; then
      m="$url"
    else
      m="$(hf_mirror_github_url "$url" "$cand")"
    fi
    local skip=0
    local t
    for t in "${tried[@]}"; do
      [[ "$t" == "$m" ]] && skip=1 && break
    done
    [[ "$skip" -eq 1 ]] && continue
    tried+=("$m")
    rm -rf "$dest"
    if git clone "$@" "$m" "$dest"; then
      return 0
    fi
  done
  return 1
}
