#!/usr/bin/env bash
# Detect whether this machine should use the ASUS power stack.

set -euo pipefail

hf_read_dmi() {
  local key="$1"
  local path="/sys/class/dmi/id/$key"
  if [[ -r "$path" ]]; then
    tr -d '\0' <"$path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
  fi
}

hf_is_asus() {
  local vendor product board
  vendor="$(hf_read_dmi sys_vendor)"
  product="$(hf_read_dmi product_name)"
  board="$(hf_read_dmi board_vendor)"

  if [[ "${HF_FORCE_PROFILE:-}" == "asus" ]]; then
    return 0
  fi
  if [[ "${HF_FORCE_PROFILE:-}" == "generic" ]]; then
    return 1
  fi

  if [[ "$vendor" == *[Aa][Ss][Uu][Ss]* || "$board" == *[Aa][Ss][Uu][Ss]* ]]; then
    return 0
  fi
  if [[ "$product" == *ROG* || "$product" == *TUF* || "$product" == *Zephyrus* || "$product" == *Vivobook* ]]; then
    return 0
  fi
  if command -v asusctl >/dev/null 2>&1 && systemctl is-active --quiet asusd 2>/dev/null; then
    return 0
  fi
  return 1
}

hf_detect_profile() {
  if hf_is_asus; then
    printf 'asus\n'
  else
    printf 'generic\n'
  fi
}

hf_vendor_summary() {
  printf '%s / %s\n' "$(hf_read_dmi sys_vendor)" "$(hf_read_dmi product_name)"
}

# Allow sourcing or direct execution.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-detect}" in
    detect) hf_detect_profile ;;
    is-asus) hf_is_asus ;;
    summary) hf_vendor_summary ;;
    *)
      echo "usage: $0 {detect|is-asus|summary}" >&2
      exit 2
      ;;
  esac
fi
