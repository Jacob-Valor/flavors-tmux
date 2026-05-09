#!/usr/bin/env bash
declare -A FORMATS=(
    ["hide"]=""
    ["arabic"]="0123456789"
    ["fsquare"]="󰎡󰎤󰎧󰎪󰎭󰎱󰎳󰎶󰎹󰎼"
    ["hsquare"]="󰎣󰎦󰎩󰎬󰎮󰎰󰎵󰎸󰎻󰎾"
    ["dsquare"]="󰎢󰎥󰎨󰎫󰎲󰎯󰎴󰎷󰎺󰎽"
    ["super"]="⁰¹²³⁴⁵⁶⁷⁸⁹"
    ["sub"]="₀₁₂₃₄₅₆₇₈₉"
    ["earabic"]="٠١٢٣٤٥٦٧٨٩"
)

ID="$1"
FORMAT="${2:-none}"

if [[ "$FORMAT" == "hide" ]]; then
    exit 0
fi

if [[ -z "${FORMATS[$FORMAT]}" ]]; then
    echo "Invalid format: $FORMAT" >&2
    exit 1
fi

format_str="${FORMATS[$FORMAT]}"
result=""

for ((i = 0; i < ${#ID}; i++)); do
    digit="${ID:$i:1}"
    char="${format_str:$digit:1}"
    result+="${char} "
done

echo -n "$result"
