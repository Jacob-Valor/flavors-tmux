#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_PATH="$CURRENT_DIR/src"

source "$SCRIPTS_PATH/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

tmux set -g status-left-length 80
tmux set -g status-right-length 150

tmux set -g mode-style "fg=${THEME[background]},bg=${THEME[foreground]},reverse"

tmux set -g message-style "bg=${THEME[primary_bright]},fg=${THEME[background]},bold"
tmux set -g message-command-style "fg=${THEME[emphasis]},bg=${THEME[surface_alt]},bold"

tmux set -g pane-border-style "fg=${THEME[surface]}"
tmux set -g pane-active-border-style "fg=${THEME[emphasis]},bold"
tmux set -g pane-border-status off

tmux set -g status-style "fg=${THEME[foreground]},bg=${THEME[background]}"

window_id_style="$(tmux show-option -gv @gruvbox-tmux_window_id_style 2>/dev/null || echo "digital")"
pane_id_style="$(tmux show-option -gv @gruvbox-tmux_pane_id_style 2>/dev/null || echo "hsquare")"
zoom_id_style="$(tmux show-option -gv @gruvbox-tmux_zoom_id_style 2>/dev/null || echo "dsquare")"
terminal_icon="$(tmux show-option -gv @gruvbox-tmux_terminal_icon 2>/dev/null || echo '')"
active_terminal_icon="$(tmux show-option -gv @gruvbox-tmux_active_terminal_icon 2>/dev/null || echo '')"

git_status="#($SCRIPTS_PATH/git-status.sh #{pane_current_path})"
wb_git_status="#($SCRIPTS_PATH/wb-git-status.sh #{pane_current_path} &)"
window_number="#($SCRIPTS_PATH/custom-number.sh #I $window_id_style)"
custom_pane="#($SCRIPTS_PATH/custom-number.sh #P $pane_id_style)"
zoom_number="#($SCRIPTS_PATH/custom-number.sh #P $zoom_id_style)"
date_and_time="$($SCRIPTS_PATH/datetime-widget.sh)"
battery_status="#($SCRIPTS_PATH/battery-widget.sh)"

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
