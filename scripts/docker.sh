#!/usr/bin/env bash
set -euo pipefail

SHOW_WIDGET=$(tmux show-option -gv @flavors-tmux_show_docker 2>/dev/null || echo 0)
if [ "$SHOW_WIDGET" == "0" ]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"

if ! command -v docker &>/dev/null; then
  exit 0
fi

CONTEXT=$(docker context show 2>/dev/null)
if [ -z "$CONTEXT" ]; then
  exit 0
fi

if [ "$CONTEXT" == "default" ]; then
  COLOR="${THEME[muted]}"
else
  COLOR="${THEME[info]}"
fi

echo "${RESET}#[fg=${COLOR},bg=${THEME[background]},bold] ${CONTEXT}"
