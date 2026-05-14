#!/usr/bin/env bash

SHOW_WIDGET=$(tmux show-option -gv @flavors-tmux_show_cwd 2>/dev/null || echo 0)
if [ "$SHOW_WIDGET" == "0" ]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"

PATH_ARG="${1:-$(pwd)}"
BASENAME=$(basename "$PATH_ARG")

GIT_ROOT=$(cd "$PATH_ARG" && git rev-parse --show-toplevel 2>/dev/null)
if [ -n "$GIT_ROOT" ]; then
  REPO_NAME=$(basename "$GIT_ROOT")
  if [ "$REPO_NAME" = "$BASENAME" ]; then
    DISPLAY="$REPO_NAME"
  else
    DISPLAY="${REPO_NAME}/${BASENAME}"
  fi
else
  DISPLAY="$BASENAME"
fi

echo "${RESET}#[fg=${THEME[emphasis]},bg=${THEME[background]},bold]󰉋 ${DISPLAY}"
