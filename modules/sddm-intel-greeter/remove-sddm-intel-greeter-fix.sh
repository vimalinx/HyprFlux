#!/usr/bin/env bash
set -euo pipefail

target_file="/etc/sddm.conf.d/10-intel-greeter.conf"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "Please run with sudo: sudo $0" >&2
  exit 1
fi

if [ -f "$target_file" ]; then
  rm -f "$target_file"
  echo "Removed: $target_file"
else
  echo "Nothing to remove: $target_file"
fi

echo "Log out and back in, or reboot, to restore previous behavior."
