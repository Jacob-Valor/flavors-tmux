#!/usr/bin/env bash

SHOW_WIDGET=$(tmux show-option -gv @flavors-tmux_show_git_worktree 2>/dev/null || echo 0)
if [ "$SHOW_WIDGET" == "0" ]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"

PATH_ARG="${1:-$(pwd)}"

cd "$PATH_ARG" || exit 0

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -z "$BRANCH" ]; then
  exit 0
fi

IS_WORKTREE=false
while IFS= read -r line; do
  if [[ "$line" == worktree* ]]; then
    WT_PATH="${line#worktree }"
    WT_PATH=$(echo "$WT_PATH" | sed 's/[[:space:]]*$//')
    if [ "$WT_PATH" == "$(pwd)" ]; then
      IS_WORKTREE=true
    fi
  fi
done < <(git worktree list --porcelain 2>/dev/null)

if [ "$IS_WORKTREE" == true ]; then
  ICON="󰙀"
  COLOR="${THEME[warning]}"
else
  ICON=""
  COLOR="${THEME[success]}"
fi

echo "${RESET}#[fg=${COLOR},bg=${THEME[background]},bold]${ICON} ${BRANCH}"
