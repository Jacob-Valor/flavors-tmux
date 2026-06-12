#!/usr/bin/env bash
set -euo pipefail
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

REMOTE_NAME=$(git remote 2>/dev/null | head -n 1)
REMOTE_URL=""
if [[ -n "$REMOTE_NAME" ]]; then
  REMOTE_URL=$(git config "remote.${REMOTE_NAME}.url" 2>/dev/null || true)
fi

PROVIDER=""
if [[ "$REMOTE_URL" =~ ^git@([^:]+): ]]; then
  PROVIDER="${BASH_REMATCH[1]}"
elif [[ "$REMOTE_URL" =~ ^https://([^/]+)/ ]]; then
  PROVIDER="${BASH_REMATCH[1]}"
fi

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
  if ! command -v gh &>/dev/null || ! command -v jq &>/dev/null; then
    exit 1
  fi
  PROVIDER_ICON="$RESET#[fg=${THEME[forge_github]}] "
  PR_COUNT=$(gh pr list --json number --limit 100 --jq 'length' 2>/dev/null || echo 0)
  REVIEW_COUNT=$(gh pr list --reviewer @me --json number --limit 100 --jq 'length' 2>/dev/null || echo 0)
  RES=$(gh issue list --json "assignees,labels" --assignee @me --limit 100 2>/dev/null || echo '[]')
  ISSUE_COUNT=$(jq 'length' <<<"$RES" 2>/dev/null || echo 0)
  BUG_COUNT=$(jq 'map(select(any(.labels[]?; .name == "bug"))) | length' <<<"$RES" 2>/dev/null || echo 0)
  ISSUE_COUNT=$((ISSUE_COUNT - BUG_COUNT))
elif [[ $PROVIDER == "gitlab.com" ]]; then
  if ! command -v glab &>/dev/null; then
    exit 1
  fi
  PROVIDER_ICON="$RESET#[fg=${THEME[forge_gitlab]}] "
  PR_COUNT=$(glab mr list 2>/dev/null | grep -cE "^\!" || true)
  REVIEW_COUNT=$(glab mr list --reviewer=@me 2>/dev/null | grep -cE "^\!" || true)
  ISSUE_COUNT=$(glab issue list 2>/dev/null | grep -cE "^\#" || true)
elif [[ $PROVIDER == "codeberg.org" ]]; then
  # Token from environment only (CWE-522 — tmux options are world-readable).
  # Set FLAVORS_TMUX_CODEBERG_TOKEN or CODEBERG_TOKEN in your shell profile.
  CODEBERG_TOKEN="${FLAVORS_TMUX_CODEBERG_TOKEN:-${CODEBERG_TOKEN:-}}"
  if [[ -z "$CODEBERG_TOKEN" ]]; then
    exit 0
  fi
  if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
    exit 1
  fi
  OWNER=""
  REPO=""
  if [[ "$REMOTE_URL" =~ codeberg.org[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
  fi
  if [[ -z "$OWNER" || -z "$REPO" ]]; then
    exit 0
  fi
  PROVIDER_ICON="$RESET#[fg=${THEME[forge_codeberg]}] "
  API_BASE="https://codeberg.org/api/v1"
  CURL_OPTS="-fsS --max-time 5"
  CURL_CONFIG="header = \"Authorization: token ${CODEBERG_TOKEN}\""

  TMP_PR=$(mktemp)
  TMP_ISSUE=$(mktemp)
  # shellcheck disable=SC2086
  (curl ${CURL_OPTS} -K <(echo "${CURL_CONFIG}") "${API_BASE}/repos/${OWNER}/${REPO}/pulls?state=open&limit=100" 2>/dev/null | jq 'length' 2>/dev/null > "$TMP_PR") &
  # shellcheck disable=SC2086
  (curl ${CURL_OPTS} -K <(echo "${CURL_CONFIG}") "${API_BASE}/repos/${OWNER}/${REPO}/issues?state=open&limit=100" 2>/dev/null | jq 'length' 2>/dev/null > "$TMP_ISSUE") &
  wait
  PR_COUNT=$(cat "$TMP_PR" 2>/dev/null || echo 0)
  ISSUE_COUNT=$(cat "$TMP_ISSUE" 2>/dev/null || echo 0)
  rm -f "$TMP_PR" "$TMP_ISSUE"
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

WB_STATUS="#[fg=${THEME[muted]},bg=${THEME[background]},bold] $RESET$PROVIDER_ICON $RESET$PR_STATUS$REVIEW_STATUS$ISSUE_STATUS$BUG_STATUS"

echo "$WB_STATUS"
