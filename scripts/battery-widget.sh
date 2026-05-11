#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
. "${ROOT_DIR}/scripts/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

SHOW_BATTERY_WIDGET=$(tmux show-option -gv @flavors-tmux_show_battery_widget 2>/dev/null)
if [[ "${SHOW_BATTERY_WIDGET}" != 1 ]]; then
    exit 0
fi

BATTERY_NAME=$(tmux show-option -gv @flavors-tmux_battery_name 2>/dev/null)
BATTERY_LOW=$(tmux show-option -gv @flavors-tmux_battery_low_threshold 2>/dev/null)
DEFAULT_BATTERY_LOW=20
BATTERY_LOW="${BATTERY_LOW:-$DEFAULT_BATTERY_LOW}"

DISCHARGING_ICONS=("󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹")
CHARGING_ICONS=("󰢜" "󰂆" "󰂇" "󰂈" "󰢝" "󰂉" "󰢞" "󰂊" "󰂋" "󰂅")
NOT_CHARGING_ICON="󰚥"
NO_BATTERY_ICON="󱉝"

case "$(uname -s)" in
    Darwin*)    default_battery_name="InternalBattery-0" ;;
    Linux*)     default_battery_name="BAT0" ;;
    *)          default_battery_name="BAT0" ;;
esac
BATTERY_NAME="${BATTERY_NAME:-$default_battery_name}"

battery_exists() {
    case "$(uname -s)" in
        Darwin*)
            pmset -g batt | grep -q "$BATTERY_NAME"
            ;;
        Linux*)
            [[ -d "/sys/class/power_supply/$BATTERY_NAME" ]]
            ;;
        CYGWIN*|MINGW*|MSYS*|Windows_NT*)
            WMIC PATH Win32_Battery Get EstimatedChargeRemaining 2>/dev/null | grep -q "EstimatedChargeRemaining"
            ;;
        *)
            return 1
            ;;
    esac
}

if ! battery_exists; then
    exit 0
fi

# Get battery stats for different OS
get_battery_stats() {
  local battery_name=$1
  local battery_status=""
  local battery_percentage=""

  case "$(uname)" in
  "Darwin")
    pmstat=$(pmset -g batt | grep "$battery_name")
    battery_status=$(echo "$pmstat" | awk '{print $4}' | sed 's/[^a-zA-Z]*//g')
    battery_percentage=$(echo "$pmstat" | awk '{print $3}' | sed 's/[^0-9]*//g')
    ;;
  "Linux")
    if [[ -f "/sys/class/power_supply/${battery_name}/status" && -f "/sys/class/power_supply/${battery_name}/capacity" ]]; then
      battery_status=$(<"/sys/class/power_supply/${battery_name}/status")
      battery_percentage=$(<"/sys/class/power_supply/${battery_name}/capacity")
    else
      battery_status="Unknown"
      battery_percentage="0"
    fi
    ;;
  "CYGWIN" | "MINGW" | "MSYS" | "Windows_NT")
    battery_percentage=$(WMIC PATH Win32_Battery Get EstimatedChargeRemaining | grep -Eo '[0-9]+')
    [[ -n $battery_percentage ]] && battery_status="Discharging" || battery_status="Unknown"
    ;;
  *)
    battery_status="UnsupportedOS"
    battery_percentage=0
    ;;
  esac

  echo "$battery_status $battery_percentage"
}

# Fetch the battery status and percentage
read -r BATTERY_STATUS BATTERY_PERCENTAGE < <(get_battery_stats "$BATTERY_NAME")

# Ensure percentage is a number
if ! [[ $BATTERY_PERCENTAGE =~ ^[0-9]+$ ]]; then
  BATTERY_PERCENTAGE=0
fi

BATTERY_ICON_INDEX=$((BATTERY_PERCENTAGE / 10))
if [[ $BATTERY_ICON_INDEX -gt 9 ]]; then
  BATTERY_ICON_INDEX=9
fi

# Determine icon and color based on battery status and percentage
case "$BATTERY_STATUS" in
"Charging" | "Charged" | "charging" | "Charged")
  ICON="${CHARGING_ICONS[$BATTERY_ICON_INDEX]}"
  ;;
"Discharging" | "discharging")
  ICON="${DISCHARGING_ICONS[$BATTERY_ICON_INDEX]}"
  ;;
"Full" | "charged" | "full" | "AC")
  ICON="$NOT_CHARGING_ICON"
  ;;
*)
  ICON="$NO_BATTERY_ICON"
  ;;
esac

if [[ "$BATTERY_PERCENTAGE" -lt "$BATTERY_LOW" ]]; then
    color="#[fg=${THEME[danger]},bg=default,bold]"
elif [[ "$BATTERY_PERCENTAGE" -ge 100 ]]; then
    color="#[fg=${THEME[success]},bg=default]"
else
    color="#[fg=${THEME[warning]},bg=default]"
fi

echo -n "${color}░ ${ICON}#[bg=default] ${BATTERY_PERCENTAGE}% "
