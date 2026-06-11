#!/usr/bin/env bash
# Map each ASCII digit [0-9] to its glyph for the requested style.
#
# Uses indexed arrays with literal UTF-8 strings so that multi-byte glyphs are
# stored as raw bytes and never passed through substring expansion or external
# commands — avoids platform-dependent UTF-8 handling entirely.

ID="$1"
FORMAT="${2:-none}"

[[ "$FORMAT" == "hide" ]] && exit 0

case "$FORMAT" in
    arabic)   glyphs=( "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" ) ;;
    earabic)  glyphs=( "٠" "١" "٢" "٣" "٤" "٥" "٦" "٧" "٨" "٩" ) ;;
    fsquare)  glyphs=( "󰎡" "󰎤" "󰎧" "󰎪" "󰎭" "󰎱" "󰎳" "󰎶" "󰎹" "󰎼" ) ;;
    hsquare)  glyphs=( "󰎣" "󰎦" "󰎩" "󰎬" "󰎮" "󰎰" "󰎵" "󰎸" "󰎻" "󰎾" ) ;;
    dsquare)  glyphs=( "󰎢" "󰎥" "󰎨" "󰎫" "󰎲" "󰎯" "󰎴" "󰎷" "󰎺" "󰎽" ) ;;
    super)    glyphs=( "⁰" "¹" "²" "³" "⁴" "⁵" "⁶" "⁷" "⁸" "⁹" ) ;;
    sub)      glyphs=( "₀" "₁" "₂" "₃" "₄" "₅" "₆" "₇" "₈" "₉" ) ;;
    *)
        echo "Invalid format: $FORMAT" >&2
        exit 1
        ;;
esac

result=""

for ((i = 0; i < ${#ID}; i++)); do
    # ID is always ASCII digits — byte-wise substring is safe here
    digit="${ID:$i:1}"
    result+="${glyphs[$digit]} "
done

echo -n "$result"
