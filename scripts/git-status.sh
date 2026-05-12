#!/usr/bin/env bash

SHOW_NETSPEED=$(tmux show-option -gv @flavors-tmux_show_git 2>/dev/null || echo 1)
if [ "$SHOW_NETSPEED" == "0" ]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

cd "$1" || exit 1
RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
STATUS=$(git status --porcelain 2>/dev/null | grep -cE "^(M| M)")

SYNC_MODE=0

if [[ ${#BRANCH} -gt 25 ]]; then
  BRANCH="${BRANCH:0:25}…"
fi

STATUS_CHANGED=""
STATUS_INSERTIONS=""
STATUS_DELETIONS=""
STATUS_UNTRACKED=""
STATUS_STASH=""
STATUS_CONFLICT=""
STATUS_AHEAD=""
STATUS_BEHIND=""

if [[ $STATUS -ne 0 ]]; then
  DIFF_COUNTS=($(git diff --numstat 2>/dev/null | awk 'NF==3 {changed+=1; ins+=$1; del+=$2} END {printf("%d %d %d", changed, ins, del)}'))
  CHANGED_COUNT=${DIFF_COUNTS[0]}
  INSERTIONS_COUNT=${DIFF_COUNTS[1]}
  DELETIONS_COUNT=${DIFF_COUNTS[2]}

  SYNC_MODE=1
fi

UNTRACKED_COUNT="$(git ls-files --other --directory --exclude-standard | wc -l)"
STASH_COUNT="$(git stash list 2>/dev/null | wc -l)"
CONFLICT_COUNT="$(git diff --name-only --diff-filter=U 2>/dev/null | wc -l)"

AHEAD_BEHIND=$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
AHEAD_COUNT=0
BEHIND_COUNT=0
if [[ -n $AHEAD_BEHIND ]]; then
  AHEAD_COUNT=$(echo "$AHEAD_BEHIND" | awk '{print $1}')
  BEHIND_COUNT=$(echo "$AHEAD_BEHIND" | awk '{print $2}')
fi

if [[ $CHANGED_COUNT -gt 0 ]]; then
  STATUS_CHANGED=" ${RESET}#[fg=${THEME[warning]},bg=${THEME[background]},bold] ${CHANGED_COUNT}"
fi

if [[ $INSERTIONS_COUNT -gt 0 ]]; then
  STATUS_INSERTIONS=" ${RESET}#[fg=${THEME[success]},bg=${THEME[background]},bold] ${INSERTIONS_COUNT}"
fi

if [[ $DELETIONS_COUNT -gt 0 ]]; then
  STATUS_DELETIONS=" ${RESET}#[fg=${THEME[danger]},bg=${THEME[background]},bold] ${DELETIONS_COUNT}"
fi

if [[ $UNTRACKED_COUNT -gt 0 ]]; then
  STATUS_UNTRACKED=" ${RESET}#[fg=${THEME[muted]},bg=${THEME[background]},bold] ${UNTRACKED_COUNT}"
fi

if [[ $STASH_COUNT -gt 0 ]]; then
  STATUS_STASH=" ${RESET}#[fg=${THEME[info_bright]},bg=${THEME[background]},bold] ${STASH_COUNT}"
fi

if [[ $CONFLICT_COUNT -gt 0 ]]; then
  STATUS_CONFLICT=" ${RESET}#[fg=${THEME[danger_bright]},bg=${THEME[background]},bold]󰅘 ${CONFLICT_COUNT}"
fi

if [[ $SYNC_MODE -eq 0 ]]; then
  if [[ $AHEAD_COUNT -gt 0 ]]; then
    SYNC_MODE=2
  elif [[ $BEHIND_COUNT -gt 0 ]]; then
    SYNC_MODE=3
  fi
fi

case "$SYNC_MODE" in
1)
  REMOTE_STATUS="$RESET#[bg=${THEME[background]},fg=${THEME[danger_bright]},bold]▒ 󱓎"
  ;;
2)
  REMOTE_STATUS="$RESET#[bg=${THEME[background]},fg=${THEME[danger]},bold]▒ 󰛃"
  ;;
3)
  REMOTE_STATUS="$RESET#[bg=${THEME[background]},fg=${THEME[info_bright]},bold]▒ 󰛀"
  ;;
*)
  REMOTE_STATUS="$RESET#[bg=${THEME[background]},fg=${THEME[success]},bold]▒ "
  ;;
esac

if [[ -n $BRANCH ]]; then
  echo "$REMOTE_STATUS $RESET$BRANCH$STATUS_CHANGED$STATUS_INSERTIONS$STATUS_DELETIONS$STATUS_UNTRACKED$STATUS_STASH$STATUS_CONFLICT "
fi
