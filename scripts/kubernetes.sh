#!/usr/bin/env bash

SHOW_WIDGET=$(tmux show-option -gv @flavors-tmux_show_kubernetes 2>/dev/null || echo 0)
if [ "$SHOW_WIDGET" == "0" ]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"

if ! command -v kubectl &>/dev/null; then
  exit 0
fi

CONTEXT=$(kubectl config current-context 2>/dev/null)
if [ -z "$CONTEXT" ]; then
  exit 0
fi

NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
NAMESPACE=${NAMESPACE:-default}

CONTEXT_LOWER=$(echo "$CONTEXT" | tr '[:upper:]' '[:lower:]')
COLOR="${THEME[info]}"
if [[ "$CONTEXT_LOWER" == *"prod"* ]] || [[ "$CONTEXT_LOWER" == *"production"* ]]; then
  COLOR="${THEME[danger]}"
elif [[ "$CONTEXT_LOWER" == *"stage"* ]] || [[ "$CONTEXT_LOWER" == *"staging"* ]] || \
     [[ "$CONTEXT_LOWER" == *"dev"* ]] || [[ "$CONTEXT_LOWER" == *"development"* ]]; then
  COLOR="${THEME[warning]}"
fi

echo "${RESET}#[fg=${COLOR},bg=${THEME[background]},bold]󱃾 ${CONTEXT}/${NAMESPACE}"
