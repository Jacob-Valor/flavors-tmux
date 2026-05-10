#!/usr/bin/env sh

name=${1:-BAT0}
low=${2:-20}
danger=${3:-#cc241d}
success=${4:-#98971a}
warning=${5:-#d79921}

status_path="/sys/class/power_supply/$name/status"
capacity_path="/sys/class/power_supply/$name/capacity"

[ -r "$status_path" ] && [ -r "$capacity_path" ] || exit 0

IFS= read -r status <"$status_path" || exit 0
IFS= read -r percentage <"$capacity_path" || exit 0

case $percentage in
    ''|*[!0-9]*) exit 0 ;;
esac

idx=$((percentage / 10))
[ "$idx" -gt 9 ] && idx=9

case $status in
    Charging|Charged|charging)
        set -- 󰢜 󰂆 󰂇 󰂈 󰢝 󰂉 󰢞 󰂊 󰂋 󰂅
        ;;
    Discharging|discharging)
        set -- 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹
        ;;
    Full|charged|full|AC)
        icon=󰚥
        ;;
    *)
        icon=󱉝
        ;;
esac

if [ -z "$icon" ]; then
    shift "$idx"
    icon=$1
fi

if [ "$percentage" -lt "$low" ]; then
    color="$danger,bold"
elif [ "$percentage" -ge 100 ]; then
    color="$success"
else
    color="$warning"
fi

printf '#[fg=%s,bg=default]░ %s#[bg=default] %s%% ' "$color" "$icon" "$percentage"
