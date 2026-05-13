#!/usr/bin/env bash

SHOW_NETSPEED=$(tmux show-option -gv @flavors-tmux_show_git 2>/dev/null || echo 1)
if [ "$SHOW_NETSPEED" == "0" ]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

cd "$1" || exit 1
RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"

# Single batched git status call for branch, changes, ahead/behind, untracked, conflicts
GIT_STATUS_V2=$(git status --porcelain=v2 --branch --untracked-files=all 2>/dev/null)
if [[ -z $GIT_STATUS_V2 ]]; then
  exit 0
fi

BRANCH=""
AHEAD_COUNT=0
BEHIND_COUNT=0
CHANGED_COUNT=0
UNTRACKED_COUNT=0
CONFLICT_COUNT=0

while IFS= read -r line; do
  case "$line" in
    "# branch.head "*)
      BRANCH="${line#\# branch.head }"
      ;;
    "# branch.ab "*)
      # Format: # branch.ab +<ahead> -<behind>
      read -r _ _ ahead_raw behind_raw <<< "$line"
      AHEAD_COUNT="${ahead_raw#+}"
      BEHIND_COUNT="${behind_raw#-}"
      ;;
    "1 "*)
      # Ordinary change: 1 <XY> <sub> <mH> <mI> ...
      xy="${line:2:2}"
      if [[ "$xy" != ".." ]]; then
        CHANGED_COUNT=$((CHANGED_COUNT + 1))
      fi
      ;;
    "2 "*)
      # Renamed or copied
      CHANGED_COUNT=$((CHANGED_COUNT + 1))
      ;;
    "u "*)
      # Unmerged (conflict)
      CONFLICT_COUNT=$((CONFLICT_COUNT + 1))
      ;;
    "? "*)
      # Untracked
      UNTRACKED_COUNT=$((UNTRACKED_COUNT + 1))
      ;;
  esac
done <<< "$GIT_STATUS_V2"

if [[ -z $BRANCH || "$BRANCH" == "HEAD" || "$BRANCH" == "(detached)" ]]; then
  exit 0
fi

if [[ ${#BRANCH} -gt 25 ]]; then
  BRANCH="${BRANCH:0:25}..."
fi

SYNC_MODE=0
STATUS_CHANGED=""
STATUS_INSERTIONS=""
STATUS_DELETIONS=""
STATUS_UNTRACKED=""
STATUS_STASH=""
STATUS_CONFLICT=""
STATUS_AHEAD=""
STATUS_BEHIND=""

if [[ $CHANGED_COUNT -ne 0 ]]; then
  DIFF_COUNTS=($(git diff --numstat HEAD 2>/dev/null | awk 'NF==3 {changed+=1; ins+=$1; del+=$2} END {printf("%d %d %d", changed, ins, del)}'))
  CHANGED_COUNT=${DIFF_COUNTS[0]}
  INSERTIONS_COUNT=${DIFF_COUNTS[1]}
  DELETIONS_COUNT=${DIFF_COUNTS[2]}
  SYNC_MODE=1
fi

STASH_COUNT="$(git stash list 2>/dev/null | wc -l)"
STASH_COUNT="${STASH_COUNT#\ *}"

if [[ $CHANGED_COUNT -gt 0 ]]; then
  STATUS_CHANGED=" ${RESET}#[fg=${THEME[warning]},bg=${THEME[background]},bold] ${CHANGED_COUNT}"
fi

if [[ ${INSERTIONS_COUNT:-0} -gt 0 ]]; then
  STATUS_INSERTIONS=" ${RESET}#[fg=${THEME[success]},bg=${THEME[background]},bold] ${INSERTIONS_COUNT}"
fi

if [[ ${DELETIONS_COUNT:-0} -gt 0 ]]; then
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

echo "$REMOTE_STATUS ${RESET}#[fg=${THEME[danger]},bg=${THEME[background]},bold] ${BRANCH}${STATUS_CHANGED}${STATUS_INSERTIONS}${STATUS_DELETIONS}${STATUS_UNTRACKED}${STATUS_STASH}${STATUS_CONFLICT} "
