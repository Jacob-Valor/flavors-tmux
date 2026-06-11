#!/usr/bin/env bash
# Custom number glyph mapping.
#
# Each style uses a comma-separated list of glyphs indexed by digit [0-9].
# Using cut(1) field extraction instead of Bash substring expansion avoids
# UTF-8 multi-byte character slicing issues on older Bash versions (macOS).
declare -A GLYPHS=(
    ["hide"]=""
    ["arabic"]="0,1,2,3,4,5,6,7,8,9"
    ["fsquare"]="󰎡,󰎤,󰎧,󰎪,󰎭,󰎱,󰎳,󰎶,󰎹,󰎼"
    ["hsquare"]="󰎣,󰎦,󰎩,󰎬,󰎮,󰎰,󰎵,󰎸,󰎻,󰎾"
    ["dsquare"]="󰎢,󰎥,󰎨,󰎫,󰎲,󰎯,󰎴,󰎷,󰎺,󰎽"
    ["super"]="⁰,¹,²,³,⁴,⁵,⁶,⁷,⁸,⁹"
    ["sub"]="₀,₁,₂,₃,₄,₅,₆,₇,₈,₉"
    ["earabic"]="٠,١,٢,٣,٤,٥,٦,٧,٨,٩"
)

ID="$1"
FORMAT="${2:-none}"

if [[ "$FORMAT" == "hide" ]]; then
    exit 0
fi

glyph_csv="${GLYPHS[$FORMAT]}"
if [[ -z "$glyph_csv" ]]; then
    echo "Invalid format: $FORMAT" >&2
    exit 1
fi

result=""

for ((i = 0; i < ${#ID}; i++)); do
    digit="${ID:$i:1}"
    # cut field index is 1-based; digit 0 → field 1
    char=$(echo "$glyph_csv" | cut -d',' -f$((digit + 1)))
    result+="${char} "
done

echo -n "$result"
