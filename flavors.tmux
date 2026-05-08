#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_PATH="$CURRENT_DIR/src"
BINARY_PATH="$CURRENT_DIR/zig-out/bin/flavors_tmux"

source "$SCRIPTS_PATH/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Widget command builders: prefer Zig binary when available
# ---------------------------------------------------------------------------

window_id_style="$(tmux show-option -gv @flavors-tmux_window_id_style 2>/dev/null || echo "digital")"
pane_id_style="$(tmux show-option -gv @flavors-tmux_pane_id_style 2>/dev/null || echo "hsquare")"
zoom_id_style="$(tmux show-option -gv @flavors-tmux_zoom_id_style 2>/dev/null || echo "dsquare")"
terminal_icon="$(tmux show-option -gv @flavors-tmux_terminal_icon 2>/dev/null || echo '')"
active_terminal_icon="$(tmux show-option -gv @flavors-tmux_active_terminal_icon 2>/dev/null || echo '')"

time_format="$(tmux show-option -gv @flavors-tmux_time_format 2>/dev/null || echo "")"

battery_name="$(tmux show-option -gv @flavors-tmux_battery_name 2>/dev/null || echo "")"
battery_low="$(tmux show-option -gv @flavors-tmux_battery_low_threshold 2>/dev/null || echo "20")"

if [[ -x "$BINARY_PATH" ]]; then
    custom_number_cmd() {
        echo "#($BINARY_PATH custom-number $1 $2)"
    }
    datetime_cmd() {
        local fmt="${time_format:-24H}"
        echo "#($BINARY_PATH datetime --theme $SELECTED_THEME --format $fmt)"
    }
    battery_cmd() {
        local name_arg=""
        [[ -n "$battery_name" ]] && name_arg="--name $battery_name"
        echo "#($BINARY_PATH battery --theme $SELECTED_THEME $name_arg --low-threshold ${battery_low:-20})"
    }
    git_status_cmd() {
        echo "#($BINARY_PATH git-status --theme $SELECTED_THEME #{pane_current_path})"
    }
    wb_git_status_cmd() {
        echo "#($BINARY_PATH wb-git-status --theme $SELECTED_THEME #{pane_current_path})"
    }
else
    custom_number_cmd() {
        echo "#($SCRIPTS_PATH/custom-number.sh $1 $2)"
    }
    datetime_cmd() {
        echo "#($SCRIPTS_PATH/datetime-widget.sh)"
    }
    battery_cmd() {
        echo "#($SCRIPTS_PATH/battery-widget.sh)"
    }
    git_status_cmd() {
        echo "#($SCRIPTS_PATH/git-status.sh #{pane_current_path})"
    }
    wb_git_status_cmd() {
        echo "#($SCRIPTS_PATH/wb-git-status.sh #{pane_current_path})"
    }
fi

tmux set -g status-left-length 80
tmux set -g status-right-length 150

tmux set -g mode-style "fg=${THEME[background]},bg=${THEME[foreground]},reverse"

tmux set -g message-style "bg=${THEME[primary_bright]},fg=${THEME[background]},bold"
tmux set -g message-command-style "fg=${THEME[emphasis]},bg=${THEME[surface_alt]},bold"

tmux set -g pane-border-style "fg=${THEME[surface]}"
tmux set -g pane-active-border-style "fg=${THEME[emphasis]},bold"
tmux set -g pane-border-status off

tmux set -g status-style "fg=${THEME[foreground]},bg=${THEME[background]}"

git_status="$(git_status_cmd)"
wb_git_status="$(wb_git_status_cmd)"
window_number="$(custom_number_cmd '#I' "$window_id_style")"
custom_pane="$(custom_number_cmd '#P' "$pane_id_style")"
zoom_number="$(custom_number_cmd '#P' "$zoom_id_style")"
date_and_time="$(datetime_cmd)"
battery_status="$(battery_cmd)"

tmux set -g status-left "\
#[fg=${THEME[foreground]},bg=${THEME[primary]},bold] \
#{?client_prefix,󰠠 ,󰤂 }\
#[bold,nodim]#S "

tmux set -g window-status-current-format "\
$RESET\
#[fg=${THEME[success_bright]},bg=${THEME[surface]}] \
#{?#{==:#{pane_current_command},ssh},󰣀 ,$active_terminal_icon }\
#[fg=${THEME[accent_bright]},bold,nodim]\
$window_number\
#W\
#[nobold]\
#{?window_zoomed_flag, $zoom_number, $custom_pane}\
#{?window_last_flag, ,}"

tmux set -g window-status-format "\
$RESET\
#[fg=${THEME[foreground]}] \
#{?#{==:#{pane_current_command},ssh},󰣀 ,$terminal_icon }\
${RESET}\
$window_number\
#W\
#[nobold,dim]\
#{?window_zoomed_flag, $zoom_number, $custom_pane}\
#[fg=${THEME[warning]}]\
#{?window_last_flag, ,}"

right_status="\
#[fg=${THEME[success]},bg=${THEME[surface_alt]}]$git_status\
#[fg=${THEME[accent]},bg=${THEME[surface_alt]}]$wb_git_status\
#[fg=${THEME[danger]},bg=${THEME[surface_alt]}]$battery_status\
#[fg=${THEME[warning]},bg=${THEME[surface_alt]}]$date_and_time"

tmux set -g status-right "$right_status"

tmux set -g window-status-separator ""
