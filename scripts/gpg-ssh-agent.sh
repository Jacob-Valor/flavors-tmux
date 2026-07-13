#!/usr/bin/env bash

SHOW_WIDGET=$(tmux show-option -gv @flavors-tmux_show_gpg_ssh_agent 2>/dev/null || echo 0)
if [ "$SHOW_WIDGET" == "0" ]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"

output=""

# ---------------------------------------------------------------------------
# SSH agent — check socket and count loaded keys
# ---------------------------------------------------------------------------
if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    if ssh_output=$(ssh-add -l 2>/dev/null); then
        if [[ "$ssh_output" != *"no identities"* ]]; then
            ssh_keys=$(echo "$ssh_output" | wc -l | tr -d ' ')
        else
            ssh_keys=0
        fi
    fi
fi

if [[ -n "${ssh_keys:-}" ]]; then
    if [[ "$ssh_keys" -gt 0 ]]; then
        color="${THEME[success]}"
    else
        color="${THEME[warning]}"
    fi
    output="${output}${RESET}#[fg=${color},bg=${THEME[surface]},bold] ${ssh_keys}"
fi

# ---------------------------------------------------------------------------
# GPG agent — try connecting via gpg-connect-agent
# ---------------------------------------------------------------------------
if command -v gpg-connect-agent &>/dev/null; then
    if gpg-connect-agent --quiet /bye &>/dev/null; then
        if [[ -n "$output" ]]; then
            output="${output} "
        fi
        output="${output}${RESET}#[fg=${THEME[success]},bg=${THEME[surface]},bold]"
    fi
fi

if [[ -n "$output" ]]; then
    echo "$output"
fi
