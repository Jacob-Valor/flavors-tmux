#!/usr/bin/env bash
SHOW_WIDGET=$(tmux show-option -gv @flavors-tmux_show_wbg 2>/dev/null || echo 1)
if [ "$SHOW_WIDGET" == "0" ]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CURRENT_DIR}/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

cd "$1" || exit 1
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
REMOTE_URL=$(git config remote.origin.url)
PROVIDER=""
if [[ "$REMOTE_URL" =~ ^git@([^:]+): ]]; then
  PROVIDER="${BASH_REMATCH[1]}"
elif [[ "$REMOTE_URL" =~ ^https://([^/]+)/ ]]; then
  PROVIDER="${BASH_REMATCH[1]}"
fi

PROVIDER_ICON=""

PR_COUNT=0
REVIEW_COUNT=0
ISSUE_COUNT=0
BUG_COUNT=0

PR_STATUS=""
REVIEW_STATUS=""
ISSUE_STATUS=""
BUG_STATUS=""

if [[ -z $BRANCH ]]; then
  exit 0
fi

if [[ $PROVIDER == "github.com" ]]; then
  if ! command -v gh &>/dev/null; then
    exit 1
  fi
  PROVIDER_ICON="$RESET#[fg=${THEME[forge_github]}] "
  PR_COUNT=$(gh pr list --json number --jq 'length')
  REVIEW_COUNT=$(gh pr status --json reviewRequests --jq '.needsReview | length')
  RES=$(gh issue list --json "assignees,labels" --assignee @me)
  ISSUE_COUNT=$(echo "$RES" | jq 'length')
  BUG_COUNT=$(echo "$RES" | jq 'map(select(any(.labels[]?; .name == "bug"))) | length')
  ISSUE_COUNT=$((ISSUE_COUNT - BUG_COUNT))
elif [[ $PROVIDER == "gitlab.com" ]]; then
  if ! command -v glab &>/dev/null; then
    exit 1
  fi
  PROVIDER_ICON="$RESET#[fg=${THEME[forge_gitlab]}] "
  PR_COUNT=$(glab mr list | grep -cE "^\!")
  REVIEW_COUNT=$(glab mr list --reviewer=@me | grep -cE "^\!")
  ISSUE_COUNT=$(glab issue list | grep -cE "^\#")
else
  exit 0
fi

if [[ $PR_COUNT -gt 0 ]]; then
  PR_STATUS="#[fg=${THEME[success]},bg=${THEME[background]},bold] ${RESET}${PR_COUNT} "
fi

if [[ $REVIEW_COUNT -gt 0 ]]; then
  REVIEW_STATUS="#[fg=${THEME[warning]},bg=${THEME[background]},bold] ${RESET}${REVIEW_COUNT} "
fi

if [[ $ISSUE_COUNT -gt 0 ]]; then
  ISSUE_STATUS="#[fg=${THEME[success]},bg=${THEME[background]},bold] ${RESET}${ISSUE_COUNT} "
fi

if [[ $BUG_COUNT -gt 0 ]]; then
  BUG_STATUS="#[fg=${THEME[danger]},bg=${THEME[background]},bold] ${RESET}${BUG_COUNT} "
fi

WB_STATUS="#[fg=${THEME[surface_alt]},bg=${THEME[background]},bold] $RESET$PROVIDER_ICON $RESET$PR_STATUS$REVIEW_STATUS$ISSUE_STATUS$BUG_STATUS"

echo "$WB_STATUS"

# Wait extra time if status-interval is less than 30 seconds to
# avoid to overload GitHub API
INTERVAL=$(tmux display -p '#{status-interval}')
if [[ $INTERVAL -lt 20 ]]; then
  sleep 20
fi
