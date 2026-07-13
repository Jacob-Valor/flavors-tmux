#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"
HOSTNAME="${HOSTNAME:-$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "unknown")}"

if [[ -n ${SSH_CONNECTION:-} || -n ${SSH_CLIENT:-} ]]; then
    echo "${RESET}#[fg=${THEME[warning]},bg=${THEME[surface]},bold]▒ 󰣀 ${HOSTNAME}"
else
    echo "${RESET}#[fg=${THEME[muted]},bg=${THEME[surface]},bold]▒ 󰌽 ${HOSTNAME}"
fi
