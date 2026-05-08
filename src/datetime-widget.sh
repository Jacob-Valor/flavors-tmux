#!/usr/bin/env bash

# Grab global variable for showing datetime widget, only hide if explicitly disabled
SHOW_DATETIME=$(tmux show-option -gv @flavors-tmux_show_time 2>/dev/null)
if [[ $SHOW_DATETIME == "0" ]]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CURRENT_DIR}/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

# Assign values based on user config
time_format=$(tmux show-option -gv @flavors-tmux_time_format 2>/dev/null)

time_string=""

case "$time_format" in
    "12H")
        time_string="%I:%M %p "
        ;;
    "hide")
        time_string=""
        ;;
    *)
        time_string="%H:%M "
        ;;
esac

separator="▒"

echo "$RESET#[fg=${THEME[accent]},bg=${THEME[surface_alt]}]$separator 󰥔 $time_string"
