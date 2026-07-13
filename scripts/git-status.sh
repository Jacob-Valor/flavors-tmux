#!/usr/bin/env bash
set -euo pipefail
# ---------------------------------------------------------------------------
# Git status widget — Bash fallback implementation.
# Uses `git status --porcelain=v2 --branch --show-stash` to consolidate what previously
# required separate rev-parse, status, rev-list, and diff-filter calls.
# ---------------------------------------------------------------------------

SHOW_GIT=$(tmux show-option -gv @flavors-tmux_show_git 2>/dev/null || echo 1)
if [ "$SHOW_GIT" == "0" ]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
source "$CURRENT_DIR/themes.sh"

if [[ -z "$1" ]]; then
    exit 0
fi
cd "$1" || exit 1
RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"

# Single git invocation replaces: rev-parse, status --porcelain, rev-list --count,
# and diff --name-only --diff-filter=U.
V2_OUTPUT=$(git status --porcelain=v2 --branch --show-stash 2>/dev/null || git status --porcelain=v2 --branch 2>/dev/null) || {
    exit 0  # Not a git repo
}

# --- Parse porcelain v2 headers ---
BRANCH=$(echo "$V2_OUTPUT" | grep "^# branch.head " | cut -d' ' -f3-) || true
if [[ "$BRANCH" == "(detached)" ]]; then
    exit 0
fi
if [[ -z "$BRANCH" ]]; then
    exit 0
fi

if [[ ${#BRANCH} -gt 25 ]]; then
    BRANCH="${BRANCH:0:25}..."
fi

AHEAD_COUNT=0
BEHIND_COUNT=0
AB_LINE=$(echo "$V2_OUTPUT" | grep "^# branch.ab ") || true
if [[ -n "$AB_LINE" ]]; then
    AHEAD_COUNT=$(echo "$AB_LINE" | sed -n 's/.*+\([0-9]*\).*/\1/p')
    BEHIND_COUNT=$(echo "$AB_LINE" | sed -n 's/.*-\([0-9]*\).*/\1/p')
    AHEAD_COUNT=${AHEAD_COUNT:-0}
    BEHIND_COUNT=${BEHIND_COUNT:-0}
fi

# --- Count file entries ---
# Changed: entries starting with 1 or 2 where XY != ".."
# The XY pair is at position 3-4 (after "1 " or "2 ")
CHANGED_COUNT=$(echo "$V2_OUTPUT" | grep -E "^[12] " | grep -cvE "^[12] \.\. ") || true
UNTRACKED_COUNT=$(echo "$V2_OUTPUT" | grep -c "^?") || true
CONFLICT_COUNT=$(echo "$V2_OUTPUT" | grep -c "^u") || true

# --- Diff stats (only if changed) ---
INSERTIONS_COUNT=0
DELETIONS_COUNT=0

SYNC_MODE=0

if [[ $CHANGED_COUNT -gt 0 ]]; then
    read -r CHANGED INSERTIONS DELETIONS < <(git diff --numstat HEAD 2>/dev/null | awk 'NF==3 {changed+=1; ins+=$1; del+=$2} END {printf("%d %d %d", changed, ins, del)}') || true
    DIFF_COUNTS=("$CHANGED" "$INSERTIONS" "$DELETIONS")
    INSERTIONS_COUNT=${DIFF_COUNTS[1]:-0}
    DELETIONS_COUNT=${DIFF_COUNTS[2]:-0}
    SYNC_MODE=1
fi

# --- Stash count ---
STASH_COUNT=$(echo "$V2_OUTPUT" | sed -n 's/^# stash //p') || true
STASH_COUNT=${STASH_COUNT:-0}

# --- Build status segments ---
STATUS_CHANGED=""
STATUS_INSERTIONS=""
STATUS_DELETIONS=""
STATUS_UNTRACKED=""
STATUS_STASH=""
STATUS_CONFLICT=""
STATUS_AHEAD=""
STATUS_BEHIND=""

if [[ $CHANGED_COUNT -gt 0 ]]; then
    STATUS_CHANGED=" ${RESET}#[fg=${THEME[warning]},bg=${THEME[surface]},bold] ${CHANGED_COUNT}"
fi

if [[ $INSERTIONS_COUNT -gt 0 ]]; then
    STATUS_INSERTIONS=" ${RESET}#[fg=${THEME[success]},bg=${THEME[surface]},bold] ${INSERTIONS_COUNT}"
fi

if [[ $DELETIONS_COUNT -gt 0 ]]; then
    STATUS_DELETIONS=" ${RESET}#[fg=${THEME[danger]},bg=${THEME[surface]},bold] ${DELETIONS_COUNT}"
fi

if [[ $UNTRACKED_COUNT -gt 0 ]]; then
    STATUS_UNTRACKED=" ${RESET}#[fg=${THEME[muted]},bg=${THEME[surface]},bold] ${UNTRACKED_COUNT}"
fi

if [[ $STASH_COUNT -gt 0 ]]; then
    STATUS_STASH=" ${RESET}#[fg=${THEME[info_bright]},bg=${THEME[surface]},bold] ${STASH_COUNT}"
fi

if [[ $CONFLICT_COUNT -gt 0 ]]; then
    STATUS_CONFLICT=" ${RESET}#[fg=${THEME[danger_bright]},bg=${THEME[surface]},bold]󰅘 ${CONFLICT_COUNT}"
fi

if [[ $AHEAD_COUNT -gt 0 ]]; then
    STATUS_AHEAD=" ${RESET}#[fg=${THEME[info_bright]},bg=${THEME[surface]},bold]↑${AHEAD_COUNT}"
fi

if [[ $BEHIND_COUNT -gt 0 ]]; then
    STATUS_BEHIND=" ${RESET}#[fg=${THEME[danger]},bg=${THEME[surface]},bold]↓${BEHIND_COUNT}"
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
    REMOTE_STATUS="$RESET#[bg=${THEME[surface]},fg=${THEME[danger_bright]},bold]▒ 󱓎"
    ;;
2)
    REMOTE_STATUS="$RESET#[bg=${THEME[surface]},fg=${THEME[danger]},bold]▒ 󰛃"
    ;;
3)
    REMOTE_STATUS="$RESET#[bg=${THEME[surface]},fg=${THEME[info_bright]},bold]▒ 󰛀"
    ;;
*)
    REMOTE_STATUS="$RESET#[bg=${THEME[surface]},fg=${THEME[success]},bold]▒ "
    ;;
esac

echo "$REMOTE_STATUS $RESET$BRANCH$STATUS_CHANGED$STATUS_INSERTIONS$STATUS_DELETIONS$STATUS_UNTRACKED$STATUS_STASH$STATUS_CONFLICT$STATUS_AHEAD$STATUS_BEHIND "
