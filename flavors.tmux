#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_PATH="$CURRENT_DIR/scripts"
BINARY_PATH="$CURRENT_DIR/zig-out/bin/flavors_tmux"

# ---------------------------------------------------------------------------
# Auto-build Zig binary if missing and Zig is available
# ---------------------------------------------------------------------------

if [[ ! -x "$BINARY_PATH" ]]; then
    if command -v zig &>/dev/null; then
        cd "$CURRENT_DIR" && zig build &>/dev/null
    fi
fi

source "$SCRIPTS_PATH/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

# Validate theme name
VALID_THEMES=("hard" "medium" "soft" "light" "tokyonight" "catppuccin" "dracula" "nord" "github_dark" "onedark" "solarized_dark" "solarized_light" "monokai" "monokai_nebula" "github_light" "ayu_dark" "ayu_light" "flexoki_dark" "flexoki_light")
if [[ ! " ${VALID_THEMES[*]} " =~ " ${SELECTED_THEME} " ]]; then
    echo "flavors-tmux: unknown theme '${SELECTED_THEME}', using 'hard'. Available: ${VALID_THEMES[*]}" >&2
    SELECTED_THEME="hard"
fi

# ---------------------------------------------------------------------------
# Widget command builders: prefer Zig binary when available
# ---------------------------------------------------------------------------

window_id_style="$(tmux show-option -gv @flavors-tmux_window_id_style 2>/dev/null || echo "hsquare")"
pane_id_style="$(tmux show-option -gv @flavors-tmux_pane_id_style 2>/dev/null || echo "hsquare")"
zoom_id_style="$(tmux show-option -gv @flavors-tmux_zoom_id_style 2>/dev/null || echo "dsquare")"
terminal_icon="$(tmux show-option -gv @flavors-tmux_terminal_icon 2>/dev/null || echo '')"
active_terminal_icon="$(tmux show-option -gv @flavors-tmux_active_terminal_icon 2>/dev/null || echo '')"

time_format="$(tmux show-option -gv @flavors-tmux_time_format 2>/dev/null || echo "")"
show_time="$(tmux show-option -gv @flavors-tmux_show_time 2>/dev/null || echo "1")"
show_git="$(tmux show-option -gv @flavors-tmux_show_git 2>/dev/null || echo "1")"
show_wbg="$(tmux show-option -gv @flavors-tmux_show_wbg 2>/dev/null || echo "1")"

battery_name="$(tmux show-option -gv @flavors-tmux_battery_name 2>/dev/null || echo "")"
battery_low="$(tmux show-option -gv @flavors-tmux_battery_low_threshold 2>/dev/null || echo "20")"
show_battery_widget="$(tmux show-option -gv @flavors-tmux_show_battery_widget 2>/dev/null || echo "0")"
forge_cache_ttl="$(tmux show-option -gv @flavors-tmux_forge_cache_ttl 2>/dev/null || echo "300")"
transparent_arg=""
[[ "$TRANSPARENT_THEME" == "1" ]] && transparent_arg="--transparent"

custom_number_format() {
    local id="$1"
    local style="$2"
    local source

    case "$id" in
        "#I") source='#{window_index}' ;;
        "#P") source='#{pane_index}' ;;
        *) source="#{l:$id}" ;;
    esac

    case "$style" in
        hide) echo "" ;;
        arabic) echo "#{s|0|0 |;s|1|1 |;s|2|2 |;s|3|3 |;s|4|4 |;s|5|5 |;s|6|6 |;s|7|7 |;s|8|8 |;s|9|9 |:$source}" ;;
        fsquare) echo "#{s|0|󰎡 |;s|1|󰎤 |;s|2|󰎧 |;s|3|󰎪 |;s|4|󰎭 |;s|5|󰎱 |;s|6|󰎳 |;s|7|󰎶 |;s|8|󰎹 |;s|9|󰎼 |:$source}" ;;
        dsquare) echo "#{s|0|󰎢 |;s|1|󰎥 |;s|2|󰎨 |;s|3|󰎫 |;s|4|󰎲 |;s|5|󰎯 |;s|6|󰎴 |;s|7|󰎷 |;s|8|󰎺 |;s|9|󰎽 |:$source}" ;;
        super) echo "#{s|0|⁰ |;s|1|¹ |;s|2|² |;s|3|³ |;s|4|⁴ |;s|5|⁵ |;s|6|⁶ |;s|7|⁷ |;s|8|⁸ |;s|9|⁹ |:$source}" ;;
        sub) echo "#{s|0|₀ |;s|1|₁ |;s|2|₂ |;s|3|₃ |;s|4|₄ |;s|5|₅ |;s|6|₆ |;s|7|₇ |;s|8|₈ |;s|9|₉ |:$source}" ;;
        earabic) echo "#{s|0|٠ |;s|1|١ |;s|2|٢ |;s|3|٣ |;s|4|٤ |;s|5|٥ |;s|6|٦ |;s|7|٧ |;s|8|٨ |;s|9|٩ |:$source}" ;;
        *) echo "#{s|0|󰎣 |;s|1|󰎦 |;s|2|󰎩 |;s|3|󰎬 |;s|4|󰎮 |;s|5|󰎰 |;s|6|󰎵 |;s|7|󰎸 |;s|8|󰎻 |;s|9|󰎾 |:$source}" ;;
    esac
}

datetime_format() {
    if [[ "$show_time" == "0" ]]; then
        echo ""
        return
    fi

    case "${time_format:-24H}" in
        12H) echo "▒ 󰥔 %I:%M %p " ;;
        hide) echo "▒ 󰥔 " ;;
        *) echo "▒ 󰥔 %H:%M " ;;
    esac
}

if [[ -x "$BINARY_PATH" ]]; then
    custom_number_cmd() {
        custom_number_format "$1" "$2"
    }
    datetime_cmd() {
        datetime_format
    }
    battery_cmd() {
        [[ "$show_battery_widget" == "1" ]] || return
        local name_arg=""
        [[ -n "$battery_name" ]] && name_arg="--name $battery_name"
        if [[ -x "$SCRIPTS_PATH/battery-fast.sh" && "$(uname -s)" == "Linux" ]]; then
            echo "#($SCRIPTS_PATH/battery-fast.sh ${battery_name:-BAT0} ${battery_low:-20} '${THEME[danger]}' '${THEME[success]}' '${THEME[warning]}')"
        else
            echo "#($BINARY_PATH battery --theme $SELECTED_THEME $transparent_arg $name_arg --low-threshold ${battery_low:-20})"
        fi
    }
    git_status_cmd() {
        [[ "$show_git" == "1" ]] || return
        echo "#($BINARY_PATH git-status --theme $SELECTED_THEME $transparent_arg #{q:pane_current_path})"
    }
    wb_git_status_cmd() {
        [[ "$show_wbg" == "1" ]] || return
        echo "#($BINARY_PATH wb-git-status --theme $SELECTED_THEME $transparent_arg --cache-ttl ${forge_cache_ttl:-300} #{q:pane_current_path})"
    }
else
    custom_number_cmd() {
        custom_number_format "$1" "$2"
    }
    datetime_cmd() {
        datetime_format
    }
    battery_cmd() {
        echo "#($SCRIPTS_PATH/battery-widget.sh)"
    }
    git_status_cmd() {
        echo "#($SCRIPTS_PATH/git-status.sh #{q:pane_current_path})"
    }
    wb_git_status_cmd() {
        echo "#($SCRIPTS_PATH/wb-git-status.sh #{q:pane_current_path})"
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
#[fg=${THEME[foreground]},bg=${THEME[primary]},bold]\
#{?client_prefix,󰠠 ,󰤂 }\
#[bold,nodim]#S"

tmux set -g window-status-current-format "\
$RESET\
#[fg=${THEME[success_bright]},bg=${THEME[surface]}]\
#{?#{==:#{pane_current_command},ssh},󰣀 ,$active_terminal_icon }\
#[fg=${THEME[accent_bright]},bold,nodim]\
$window_number\
#W\
#[nobold]\
#{?window_zoomed_flag, $zoom_number, $custom_pane}\
#{?window_last_flag, ,}"

tmux set -g window-status-format "\
$RESET\
#[fg=${THEME[foreground]}]\
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

# ---------------------------------------------------------------------------
# Auto-update check (runs in background)
# ---------------------------------------------------------------------------

auto_update="$(tmux show-option -gv @flavors-tmux_auto_update 2>/dev/null || echo "0")"
if [[ "$auto_update" == "1" ]]; then
    ("$SCRIPTS_PATH/auto-update.sh" &)
fi
