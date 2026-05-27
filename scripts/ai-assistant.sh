#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
. "${ROOT_DIR}/scripts/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

SHOW_AI_ASSISTANT=$(tmux show-option -gv @flavors-tmux_show_ai_assistant 2>/dev/null)
if [[ "${SHOW_AI_ASSISTANT}" != 1 ]]; then
    exit 0
fi

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"

# Known AI assistants in the same order as the Zig widget
# Format: "display_name:process_name1,process_name2,..."
KNOWN_ASSISTANTS=(
    "claude:claude"
    "aider:aider"
    "copilot:github-copilot"
    "ollama:ollama"
    "cursor:cursor"
    "codeium:codeium"
    "windsurf:windsurf"
    "gemini:gemini"
    "lmstudio:lmstudio"
    "continue:continue"
    "opencode:opencode"
    "pi:pi-coding-agent"
    "commandcode:commandcode"
)

is_process_running() {
    local process_names="$1"
    IFS=',' read -ra procs <<< "$process_names"
    for proc_name in "${procs[@]}"; do
        if pgrep -x "$proc_name" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

active_assistants=()
for entry in "${KNOWN_ASSISTANTS[@]}"; do
    name="${entry%%:*}"
    processes="${entry#*:}"
    if is_process_running "$processes"; then
        active_assistants+=("$name")
    fi
done

if [[ ${#active_assistants[@]} -eq 0 ]]; then
    exit 0
fi

assistant_list=$(IFS=,; echo "${active_assistants[*]}")

echo -n "${RESET}#[fg=${THEME[success]},bg=${THEME[background]},bold]▒   ${assistant_list}"
