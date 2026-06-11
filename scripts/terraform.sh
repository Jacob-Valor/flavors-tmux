#!/usr/bin/env bash
set -euo pipefail

SHOW_WIDGET=$(tmux show-option -gv @flavors-tmux_show_terraform 2>/dev/null || echo 0)
if [ "$SHOW_WIDGET" == "0" ]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"

PATH_ARG="${1:-$(pwd)}"

cd "$PATH_ARG" || exit 0

if ! command -v terraform &>/dev/null; then
  exit 0
fi

WORKSPACE=$(terraform workspace show 2>/dev/null)
if [ -z "$WORKSPACE" ]; then
  exit 0
fi

if [ "$WORKSPACE" == "default" ]; then
  COLOR="${THEME[muted]}"
else
  COLOR="${THEME[primary]}"
fi

echo "${RESET}#[fg=${COLOR},bg=${THEME[background]},bold]󱁢 ${WORKSPACE}"
