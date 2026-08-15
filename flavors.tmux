#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_PATH="$CURRENT_DIR/scripts"
BINARY_PATH="$CURRENT_DIR/target/release/flavors_tmux"

# ---------------------------------------------------------------------------
# Auto-build Rust binary if missing and Cargo is available.
# Runs in background so tmux startup is not blocked — Bash fallback
# handles widgets until the binary is ready on next reload.
# ---------------------------------------------------------------------------

if [[ ! -x "$BINARY_PATH" ]]; then
    if command -v cargo &>/dev/null; then
        (cd "$CURRENT_DIR" && cargo build --release &>/dev/null &)
    fi
fi

source "$SCRIPTS_PATH/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

# Validate theme name
# BEGIN_CODEGEN_VALID_THEMES
VALID_THEMES=("hard" "medium" "soft" "light" "tokyonight" "catppuccin" "dracula" "nord" "github_dark" "onedark" "solarized_dark" "solarized_light" "monokai" "monokai_nebula" "github_light" "ayu_dark" "ayu_light" "flexoki_dark" "flexoki_light" "rose_pine" "rose_pine_dawn" "everforest" "kanagawa")
# END_CODEGEN_VALID_THEMES
CUSTOM_THEME_PATH=""
if [[ "$SELECTED_THEME" =~ ^[A-Za-z0-9_-]+$ ]]; then
    CUSTOM_THEME_PATH="${HOME}/.config/flavors-tmux/themes/${SELECTED_THEME}.json"
fi
theme_valid=false
for vt in "${VALID_THEMES[@]}"; do
    [[ "$vt" == "$SELECTED_THEME" ]] && theme_valid=true && break
done
if [[ $theme_valid == false && ( -z "$CUSTOM_THEME_PATH" || ! -f "$CUSTOM_THEME_PATH" ) ]]; then
    echo "flavors-tmux: unknown theme '${SELECTED_THEME}', using 'monokai_nebula'. Available: ${VALID_THEMES[*]}" >&2
    SELECTED_THEME="monokai_nebula"
fi

# ---------------------------------------------------------------------------
# Configuration option reads (single tmux roundtrip)
# ---------------------------------------------------------------------------

declare -A _opt
while IFS=' ' read -r _key _val; do
    _opt["${_key#@flavors-tmux_}"]="$_val"
done < <(tmux show-options -g 2>/dev/null | grep '^@flavors-tmux_' || true)

window_id_style="${_opt[window_id_style]:-hsquare}"
zoom_id_style="${_opt[zoom_id_style]:-dsquare}"
terminal_icon="${_opt[terminal_icon]:-}"
active_terminal_icon="${_opt[active_terminal_icon]:-}"
# Escape # to ## in user-supplied icon values to prevent tmux format injection
# (CWE-94 — #(command) or #[style] embedded in icon strings).
# Also handles #{variable} injection since ##{ renders as literal #{ in tmux.
terminal_icon="${terminal_icon//#/##}"
active_terminal_icon="${active_terminal_icon//#/##}"

time_format="${_opt[time_format]:-}"
show_time="${_opt[show_time]:-1}"
show_git="${_opt[show_git]:-1}"
show_wbg="${_opt[show_wbg]:-1}"

battery_name="${_opt[battery_name]:-}"
battery_low="${_opt[battery_low_threshold]:-20}"
show_battery_widget="${_opt[show_battery_widget]:-0}"
show_cpu_memory="${_opt[show_cpu_memory]:-0}"
show_kubernetes="${_opt[show_kubernetes]:-0}"
show_cwd="${_opt[show_cwd]:-0}"
show_gpg_ssh_agent="${_opt[show_gpg_ssh_agent]:-0}"
forge_cache_ttl="${_opt[forge_cache_ttl]:-300}"
auto_update="${_opt[auto_update]:-0}"
status_interval="${_opt[status_interval]:-15}"
status_left_length="${_opt[status_left_length]:-80}"
status_right_length="${_opt[status_right_length]:-150}"
separator_style="${_opt[separator_style]:-space}"
window_status_style="${_opt[window_status_style]:-pill}"
show_session_in_window="${_opt[show_session_in_window]:-0}"

# Validate numeric fields and identifiers to prevent injection in #(...) shell commands
[[ "$battery_low" =~ ^[0-9]+$ ]] || battery_low=20
[[ "$forge_cache_ttl" =~ ^[0-9]+$ ]] || forge_cache_ttl=300
[[ "$status_interval" =~ ^[0-9]+$ ]] || status_interval=15
[[ "$status_interval" -ge 1 && "$status_interval" -le 3600 ]] || status_interval=15
[[ "$status_left_length" =~ ^[0-9]+$ ]] || status_left_length=80
[[ "$status_right_length" =~ ^[0-9]+$ ]] || status_right_length=150
[[ "$separator_style" =~ ^(space|pipe|chevron|arrow|slash|line|block|none)$ ]] || separator_style=space
[[ "$window_status_style" =~ ^(pill|border)$ ]] || window_status_style=pill
[[ "$show_session_in_window" =~ ^[01]$ ]] || show_session_in_window=0
[[ "$battery_name" =~ ^[A-Za-z0-9_-]+$ ]] || battery_name=""

transparent_arg=""
[[ "$TRANSPARENT_THEME" == "1" ]] && transparent_arg="--transparent"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Emit a tmux #() shell command only if the named show_* flag is "1".
# Always returns 0 — the caller wraps this in `$(...)` command substitution
# and `set -e` would abort the whole script if this returned non-zero when a
# widget flag is off (previously the Bash fallback status-right was never
# set whenever any optional widget was disabled).
# Usage: if_enabled show_git "#($BINARY_PATH git-status ...)"
if_enabled() {
    local flag_var="$1"
    local cmd="$2"
    if [[ "${!flag_var}" == "1" ]]; then
        echo "$cmd"
    fi
    return 0
}

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

FLAVORS_OS="$(uname -s)"

# ---------------------------------------------------------------------------
# Widget command builders: identical in both binary and bash branches
# ---------------------------------------------------------------------------

custom_number_cmd() { custom_number_format "$1" "$2"; }
datetime_cmd() { datetime_format; }

# ---------------------------------------------------------------------------
# Widget command builders: binary path overrides
# ---------------------------------------------------------------------------

if [[ -x "$BINARY_PATH" ]]; then
    battery_cmd() {
        [[ "$show_battery_widget" == "1" ]] || return
        local escaped_name
        printf -v escaped_name '%q' "${battery_name:-BAT0}"
        local name_arg=""
        [[ -n "$battery_name" ]] && name_arg="--name ${escaped_name}"
        if [[ -x "$SCRIPTS_PATH/battery-fast.sh" && "$FLAVORS_OS" == "Linux" ]]; then
            echo "#($SCRIPTS_PATH/battery-fast.sh ${escaped_name} ${battery_low:-20} '${THEME[danger]}' '${THEME[success]}' '${THEME[warning]}')"
        else
            echo "#($BINARY_PATH battery --theme $SELECTED_THEME $transparent_arg ${name_arg} --low-threshold ${battery_low:-20})"
        fi
    }
    git_status_cmd() {
        if_enabled show_git "#($BINARY_PATH git-status --theme $SELECTED_THEME $transparent_arg #{q:pane_current_path})"
    }
    wb_git_status_cmd() {
        if_enabled show_wbg "#($BINARY_PATH wb-git-status --theme $SELECTED_THEME $transparent_arg --cache-ttl ${forge_cache_ttl:-300} #{q:pane_current_path})"
    }
    cpu_memory_cmd() {
        if_enabled show_cpu_memory "#($BINARY_PATH cpu-memory --theme $SELECTED_THEME $transparent_arg)"
    }
    kubernetes_cmd() {
        if_enabled show_kubernetes "#($BINARY_PATH kubernetes --theme $SELECTED_THEME $transparent_arg)"
    }
    cwd_cmd() {
        if_enabled show_cwd "#($BINARY_PATH cwd --theme $SELECTED_THEME $transparent_arg #{q:pane_current_path})"
    }
    gpg_ssh_agent_cmd() {
        if_enabled show_gpg_ssh_agent "#($BINARY_PATH gpg-ssh-agent --theme $SELECTED_THEME $transparent_arg)"
    }
else
    battery_cmd() {
        echo "#($SCRIPTS_PATH/battery-widget.sh)"
    }
    git_status_cmd() {
        if_enabled show_git "#($SCRIPTS_PATH/git-status.sh #{q:pane_current_path})"
    }
    wb_git_status_cmd() {
        if_enabled show_wbg "#($SCRIPTS_PATH/wb-git-status.sh #{q:pane_current_path})"
    }
    cpu_memory_cmd() {
        if_enabled show_cpu_memory "#($SCRIPTS_PATH/cpu-memory.sh)"
    }
    kubernetes_cmd() {
        if_enabled show_kubernetes "#($SCRIPTS_PATH/kubernetes.sh)"
    }
    cwd_cmd() {
        if_enabled show_cwd "#($SCRIPTS_PATH/cwd.sh #{q:pane_current_path})"
    }
    gpg_ssh_agent_cmd() {
        if_enabled show_gpg_ssh_agent "#($SCRIPTS_PATH/gpg-ssh-agent.sh)"
    }
fi

tmux set -g status-left-length "$status_left_length"
tmux set -g status-right-length "$status_right_length"
# Refresh cadence: how often tmux re-runs the statusline #() commands.
# Higher = fewer subprocess spawns (and fewer forge cache expiries), lower =
# more responsive git/branch changes. Default 15s matches tmux's default.
tmux set -g status-interval "$status_interval"

tmux set -g mode-style "fg=${THEME[background]},bg=${THEME[foreground]},reverse"

tmux set -g message-style "bg=${THEME[primary_bright]},fg=${THEME[on_primary_bright]},bold"
tmux set -g message-command-style "fg=${THEME[emphasis]},bg=${THEME[surface_alt]},bold"

tmux set -g pane-border-style "fg=${THEME[surface]}"
tmux set -g pane-active-border-style "fg=${THEME[emphasis]},bold"
tmux set -g pane-border-status off

tmux set -g status-style "fg=${THEME[foreground]},bg=${THEME[background]}"

tmux set -g status-left "\
$RESET\
#{?client_prefix,\
#[fg=${THEME[on_primary]},bg=${THEME[warning]},bold] 󰠠 #{prefix} ,\
#[fg=${THEME[primary]}] 󰠠 }\
#[fg=${THEME[foreground]},bold,nodim] #S "

window_number="$(custom_number_cmd '#I' "$window_id_style")"
zoom_number="$(custom_number_cmd '#P' "$zoom_id_style")"
window_status_border=""
window_name_prefix=""
[[ "$window_status_style" == "border" ]] && window_status_border="#[fg=${THEME[emphasis]}]▏#[fg=${THEME[on_primary_bright]},bg=${THEME[primary_bright]},bold,nodim]"
[[ "$show_session_in_window" == "1" ]] && window_name_prefix="#S:"

tmux set -g window-status-current-format "\
$RESET\
#[fg=${THEME[on_primary_bright]},bg=${THEME[primary_bright]}] \
#{?#{==:#{pane_current_command},ssh},󰣀 ,$active_terminal_icon }\
#[fg=${THEME[on_primary_bright]},bg=${THEME[primary_bright]},bold,nodim]\
$window_number\
$window_status_border\
$window_name_prefix#W\
#[nobold]\
#{?window_zoomed_flag,  $zoom_number,}\
#{?window_last_flag, ,}"

tmux set -g window-status-format "\
$RESET\
#[fg=${THEME[foreground]},bg=${THEME[surface]}] \
#{?#{==:#{pane_current_command},ssh},󰣀 ,$terminal_icon }\
$window_number\
#W\
#[fg=${THEME[muted]}]\
#{?window_zoomed_flag,  $zoom_number,}\
#[fg=${THEME[warning]}]\
#{?window_last_flag, ,}"

# Build comma-separated list of active widget names
ACTIVE_WIDGETS=""
[[ "$show_cwd" == "1" ]] && ACTIVE_WIDGETS="${ACTIVE_WIDGETS}cwd,"
[[ "$show_git" == "1" ]] && ACTIVE_WIDGETS="${ACTIVE_WIDGETS}git,"
[[ "$show_wbg" == "1" ]] && ACTIVE_WIDGETS="${ACTIVE_WIDGETS}wb-git,"
[[ "$show_cpu_memory" == "1" ]] && ACTIVE_WIDGETS="${ACTIVE_WIDGETS}cpu,"
[[ "$show_battery_widget" == "1" ]] && ACTIVE_WIDGETS="${ACTIVE_WIDGETS}battery,"
[[ "$show_kubernetes" == "1" ]] && ACTIVE_WIDGETS="${ACTIVE_WIDGETS}kubernetes,"
[[ "$show_gpg_ssh_agent" == "1" ]] && ACTIVE_WIDGETS="${ACTIVE_WIDGETS}gpg-ssh,"
[[ "$show_time" == "1" ]] && ACTIVE_WIDGETS="${ACTIVE_WIDGETS}datetime,"
ACTIVE_WIDGETS="${ACTIVE_WIDGETS%,}"

if [[ -x "$BINARY_PATH" && -n "$ACTIVE_WIDGETS" ]]; then
    battery_name_opt=""
    [[ -n "$battery_name" ]] && printf -v battery_name_opt -- '--name %q' "$battery_name"
    status_right="#($BINARY_PATH status --theme $SELECTED_THEME $transparent_arg \
  --pane-path '#{q:pane_current_path}' \
  $ACTIVE_WIDGETS \
  $battery_name_opt \
  --low-threshold ${battery_low:-20} \
  --format ${time_format:-24H} \
  --cache-ttl ${forge_cache_ttl:-300} \
  --separator ${separator_style:-space})"
    tmux set -g status-right "$status_right"
else
    # Fallback: assemble from individual bash widget scripts
    git_status="$(git_status_cmd)"
    wb_git_status="$(wb_git_status_cmd)"
    date_and_time="$(datetime_cmd)"
    battery_status="$(battery_cmd)"
    cpu_memory_status="$(cpu_memory_cmd)"
    kubernetes_status="$(kubernetes_cmd)"
    cwd_status="$(cwd_cmd)"
    gpg_ssh_agent_status="$(gpg_ssh_agent_cmd)"

    case "${separator_style:-space}" in
        pipe) _sep="│" ;;
        chevron) _sep="〉" ;;
        arrow) _sep="▸" ;;
        slash) _sep="/" ;;
        line) _sep="━" ;;
        block) _sep="▏" ;;
        *) _sep="" ;;
    esac
    # "space"/"none"/default emit no glyph — the per-segment padding gap
    # provides the inter-segment spacing, matching the Rust `status` renderer.
    if [[ "${separator_style:-space}" == "pipe" || "${separator_style:-space}" == "chevron" || "${separator_style:-space}" == "arrow" || "${separator_style:-space}" == "slash" || "${separator_style:-space}" == "line" || "${separator_style:-space}" == "block" ]]; then
        :
    else
        _sep=""
    fi

    right_status_parts=()
    [[ -n "$cwd_status" ]] && right_status_parts+=("#[fg=${THEME[emphasis]},bg=${THEME[surface]}]$cwd_status")
    [[ -n "$git_status" ]] && right_status_parts+=("#[fg=${THEME[success]},bg=${THEME[surface]}]$git_status")
    [[ -n "$wb_git_status" ]] && right_status_parts+=("#[fg=${THEME[accent]},bg=${THEME[surface]}]$wb_git_status")
    [[ -n "$cpu_memory_status" ]] && right_status_parts+=("#[fg=${THEME[accent_bright]},bg=${THEME[surface]}]$cpu_memory_status")
    [[ -n "$battery_status" ]] && right_status_parts+=("#[fg=${THEME[danger]},bg=${THEME[surface]}]$battery_status")
    [[ -n "$kubernetes_status" ]] && right_status_parts+=("#[fg=${THEME[info]},bg=${THEME[surface]}]$kubernetes_status")
    [[ -n "$gpg_ssh_agent_status" ]] && right_status_parts+=("#[fg=${THEME[primary_bright]},bg=${THEME[surface]}]$gpg_ssh_agent_status")
    [[ -n "$date_and_time" ]] && right_status_parts+=("#[fg=${THEME[warning]},bg=${THEME[surface]}]$date_and_time")

    # Assemble segments matching the Rust `status` renderer: separator glyph
    # between segments and one trailing space of padding inside each
    # non-final segment so widgets read as distinct blocks.
    right_status=""
    for ((i = 0; i < ${#right_status_parts[@]}; i++)); do
        if [[ -n "$right_status" ]]; then
            right_status="${right_status}${_sep}"
        fi
        right_status="${right_status}${right_status_parts[$i]}"
        if [[ $((i + 1)) -lt ${#right_status_parts[@]} ]]; then
            # Padding: one space separates this segment from the next.
            right_status="${right_status} "
        fi
    done
    tmux set -g status-right "$right_status"
fi

tmux set -g window-status-separator ""

# ---------------------------------------------------------------------------
# Auto-update check (runs in background)
# ---------------------------------------------------------------------------

if [[ "$auto_update" == "1" ]]; then
    ("$SCRIPTS_PATH/auto-update.sh" &)
fi
