#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Regression guard for the status-left prefix banner, session icon, and the
# active-window pill in flavors.tmux.
#
# The prefix banner must pair its warning background with the theme-designed
# on_primary contrast color. The session renders as a plain primary icon on
# the bar background (no fill), so it can never collide with the
# active-window pill. The active-window pill must pair primary_bright with
# its designed on_primary_bright — rather than an unrelated field like
# `surface`, whose contrast against the surrounding bar background is not
# guaranteed by the theme system and is near-invisible in several themes
# (e.g. monokai_nebula, solarized_light). See git history on this file for
# the incident that prompted this check.
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$(dirname "$SCRIPT_DIR")/flavors.tmux"

fail=0

assert_contains() {
    local desc="$1" pattern="$2"
    if ! grep -qF -- "$pattern" "$FILE"; then
        echo "FAIL: $desc" >&2
        echo "  expected to find literal text: $pattern" >&2
        fail=1
    fi
}

# shellcheck disable=SC2016
assert_contains \
    "prefix banner (status-left) must pair bg=warning with fg=on_primary" \
    'fg=${THEME[on_primary]},bg=${THEME[warning]},bold] 󰠠 #{prefix}'

# shellcheck disable=SC2016
assert_contains \
    "session icon (status-left) uses primary as foreground on the bar background" \
    '#[fg=${THEME[primary]}] 󰠠 }'

# shellcheck disable=SC2016
assert_contains \
    "active-window pill (window-status-current-format) must pair bg=primary_bright with fg=on_primary_bright" \
    'fg=${THEME[on_primary_bright]},bg=${THEME[primary_bright]},bold,nodim]'

if [[ $fail -ne 0 ]]; then
    echo "" >&2
    echo "One or more statusline pills no longer use a designed on-color pair." >&2
    exit 1
fi

echo "OK: statusline pills use designed on-color pairs"
