#!/usr/bin/env bash
# Optionally prefer China Arch mirrors when GitHub is blocked / HF_CN=1.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/scripts/ui.sh"

TTY_IN="${HF_TTY:-/dev/tty}"
[[ -r "$TTY_IN" ]] || TTY_IN="/dev/stdin"

HF_CN="${HF_CN:-0}"
need=0
if [[ "$HF_CN" == "1" ]]; then
  need=1
elif ! curl -fsSIL --connect-timeout 3 --max-time 6 -o /dev/null https://github.com/ >/dev/null 2>&1; then
  need=1
fi

if [[ "$need" != "1" ]]; then
  exit 0
fi

mirrorlist="/etc/pacman.d/mirrorlist"
if [[ ! -w "$mirrorlist" ]] && ! command -v sudo >/dev/null 2>&1; then
  hf_warn "Cannot update pacman mirrorlist (no sudo)"
  exit 0
fi

if grep -qE 'mirrors\.(tuna\.tsinghua|ustc|aliyun)\.' "$mirrorlist" 2>/dev/null; then
  hf_ok "China Arch mirrors already present in mirrorlist"
  exit 0
fi

hf_info "Prepending China Arch mirrors (TUNA / USTC / Aliyun)"
tmp="$(mktemp)"
cat >"$tmp" <<'EOF'
## HyprFlux China mirrors (prepended)
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.aliyun.com/archlinux/$repo/os/$arch

EOF
cat "$mirrorlist" >>"$tmp"
sudo cp "$mirrorlist" "${mirrorlist}.hyprflux-bak.$(date +%Y%m%d-%H%M%S)" <"$TTY_IN"
sudo cp "$tmp" "$mirrorlist" <"$TTY_IN"
rm -f "$tmp"
hf_ok "pacman mirrorlist updated"
