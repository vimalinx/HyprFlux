#!/usr/bin/env bash
set -euo pipefail

target_dir="/etc/sddm.conf.d"
target_file="$target_dir/10-intel-greeter.conf"
backup_file="$target_file.bak.$(date +%Y%m%d-%H%M%S)"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "Please run with sudo: sudo $0" >&2
  exit 1
fi

mkdir -p "$target_dir"

if [ -f "$target_file" ]; then
  cp "$target_file" "$backup_file"
  echo "Backed up existing file to: $backup_file"
fi

install -m 0644 "$(dirname "$0")/10-intel-greeter.conf" "$target_file"

echo "Installed: $target_file"
echo "Log out and back in, or reboot."
echo "If the greeter fails, switch to a TTY and run remove-sddm-intel-greeter-fix.sh."
