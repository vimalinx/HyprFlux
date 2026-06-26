#!/usr/bin/env bash
set -eu

colors_file="${HOME}/.config/kitty/kitty-colors.conf"

read_color() {
  local key="$1"
  local fallback="$2"
  local value=""

  if [[ -f "$colors_file" ]]; then
    value="$(awk -v key="$key" '$1 == key { print $2; exit }' "$colors_file")"
  fi

  if [[ -n "$value" ]]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}

command -v tmux >/dev/null 2>&1 || exit 0

bg="$(read_color background "#1B1C1D")"
fg="$(read_color foreground "#EFF2F5")"
muted="$(read_color color6 "#9CA4AA")"
subtle="$(read_color color0 "#424344")"
accent="$(read_color color4 "#506B8A")"
accent_soft="$(read_color color2 "#334356")"
accent_bright="$(read_color color12 "#6B8FB8")"
highlight="$(read_color color14 "#D0DAE2")"

status_left="#[fg=${accent_bright},bold] #S "
status_right="#{?client_prefix,#[fg=${bg},bg=${accent_bright},bold] PREFIX #[default] ,}#[fg=${accent}]%H:%M #[fg=${muted}]%Y-%m-%d "
window_current="#[fg=${fg},bg=${accent_soft},bold] #I:#W #[default]"

tmux set-option -gq status-position bottom
tmux set-option -gq status-justify centre
tmux set-option -gq status-style "bg=default,fg=${muted}"
tmux set-option -gq status-left-length 24
tmux set-option -gq status-right-length 48
tmux set-option -gq status-left "$status_left"
tmux set-option -gq status-right "$status_right"
tmux set-option -gq message-style "bg=${accent},fg=${fg}"
tmux set-option -gq message-command-style "bg=${accent},fg=${fg}"
tmux set-option -gq mode-style "bg=${accent},fg=${fg}"
tmux set-option -gq pane-border-style "fg=${subtle}"
tmux set-option -gq pane-active-border-style "fg=${accent}"

tmux set-window-option -gq window-status-separator " "
tmux set-window-option -gq window-status-style "fg=${muted}"
tmux set-window-option -gq window-status-format "#[fg=${muted}] #I:#W "
tmux set-window-option -gq window-status-current-format "$window_current"
tmux set-window-option -gq window-status-activity-style "fg=${accent_bright},bold"
tmux set-window-option -gq window-status-bell-style "fg=${bg},bg=${highlight},bold"
