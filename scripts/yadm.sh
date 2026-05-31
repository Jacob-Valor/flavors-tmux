#!/usr/bin/env bash
set -euo pipefail

SHOW_WIDGET=$(tmux show-option -gv @flavors-tmux_show_yadm 2>/dev/null || echo 0)
if [ "$SHOW_WIDGET" == "0" ]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"

if ! command -v yadm &>/dev/null; then
  exit 0
fi

STATUS=$(yadm status --porcelain 2>/dev/null)
if [ -z "$STATUS" ]; then
  echo "${RESET}#[fg=${THEME[muted]},bg=${THEME[background]},bold]󰃣"
  exit 0
fi

CHANGED=$(echo "$STATUS" | grep -cE '^(M| A| D|R|C|U| M| A| D)') || true
UNTRACKED=$(echo "$STATUS" | grep -cE '^\?\?') || true

STATUS_STR=""
if [ "$CHANGED" -gt 0 ]; then
  STATUS_STR="${STATUS_STR}#[fg=${THEME[warning]},bg=${THEME[background]},bold] ${CHANGED}"
fi
if [ "$UNTRACKED" -gt 0 ]; then
  STATUS_STR="${STATUS_STR}#[fg=${THEME[muted]},bg=${THEME[background]},bold] ${UNTRACKED}"
fi

echo "${RESET}󰃣 ${STATUS_STR}"
