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

# Single kubectl call gets both context name and namespace (newline separated)
KUBE_OUTPUT=$(kubectl config view --minify --output 'jsonpath={.contexts[0].name}{"\n"}{.contexts[0].context.namespace}{"\n"}' 2>/dev/null)
if [ -z "$KUBE_OUTPUT" ]; then
  exit 0
fi

{
  read -r CONTEXT
  read -r NAMESPACE
} <<< "$KUBE_OUTPUT"
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
