#!/usr/bin/env bash
# Auto-update checker for flavors-tmux.
# Compares local HEAD with the remote origin and optionally auto-pulls.

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/flavors-tmux"
CACHE_FILE="$CACHE_DIR/last-update-check"

# ---------------------------------------------------------------------------
# Configuration (read from tmux options)
# ---------------------------------------------------------------------------

AUTO_UPDATE="$(tmux show-option -gv @flavors-tmux_auto_update 2>/dev/null || echo "0")"
AUTO_UPDATE_PULL="$(tmux show-option -gv @flavors-tmux_auto_update_pull 2>/dev/null || echo "0")"
INTERVAL_HOURS="$(tmux show-option -gv @flavors-tmux_auto_update_interval 2>/dev/null || echo "24")"
BRANCH="$(tmux show-option -gv @flavors-tmux_auto_update_branch 2>/dev/null || echo "main")"

if [[ "$AUTO_UPDATE" != "1" ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# Ensure cache directory exists
# ---------------------------------------------------------------------------

mkdir -p "$CACHE_DIR"

# ---------------------------------------------------------------------------
# Throttle: only check once per interval
# ---------------------------------------------------------------------------

now=$(date +%s)
last_check=0
if [[ -f "$CACHE_FILE" ]]; then
    last_check=$(cat "$CACHE_FILE")
fi

if [[ ! "$INTERVAL_HOURS" =~ ^[0-9]+$ ]]; then
    INTERVAL_HOURS=24
fi
interval_seconds=$((INTERVAL_HOURS * 3600))
if (( now - last_check < interval_seconds )); then
    exit 0
fi

# ---------------------------------------------------------------------------
# Check for updates
# ---------------------------------------------------------------------------

cd "$CURRENT_DIR" || exit 0

# Must be a git repo with a remote
if ! git rev-parse --git-dir &>/dev/null; then
    exit 0
fi

# Detect remote name (not hardcoded to origin)
remote_name=$(git remote 2>/dev/null | head -n 1)
if [[ -z "$remote_name" ]]; then
    exit 0
fi

remote_url=$(git config --get "remote.${remote_name}.url" 2>/dev/null || true)
if [[ -z "$remote_url" ]]; then
    exit 0
fi

# Verify remote URL is the expected flavors-tmux repository (CWE-494).
# This prevents a compromised or swapped remote from injecting malicious code.
if [[ ! "$remote_url" =~ ^(github\.com:Jacob-Valor/flavors-tmux|git@github\.com:Jacob-Valor/flavors-tmux|https://github\.com/Jacob-Valor/flavors-tmux)(\.git)?$ ]]; then
    tmux display-message "flavors-tmux: auto-update skipped — remote URL '${remote_url}' is not the expected repository"
    exit 0
fi

local_head=$(git rev-parse HEAD 2>/dev/null || true)
remote_head=$(git ls-remote --heads "$remote_name" "$BRANCH" 2>/dev/null | awk '{print $1}')

if [[ -z "$local_head" || -z "$remote_head" ]]; then
    exit 0
fi

if [[ "$local_head" == "$remote_head" ]]; then
    exit 0
fi

# Only update cache after successful validation
echo "$now" > "$CACHE_FILE"

# ---------------------------------------------------------------------------
# Notify user or auto-pull
# ---------------------------------------------------------------------------

if [[ "$AUTO_UPDATE_PULL" == "1" ]]; then
    tmux display-message "flavors-tmux: updating plugin..."
    if git pull "$remote_name" "$BRANCH" --ff-only &>/dev/null; then
        # Rebuild binary if Zig is available
        if command -v zig &>/dev/null; then
            zig build &>/dev/null || true
        fi
        tmux display-message "flavors-tmux: plugin updated — reload tmux config to apply"
    else
        tmux display-message "flavors-tmux: auto-update failed — check git status"
    fi
else
    # Just notify
    tmux display-message "flavors-tmux: update available — run prefix + U in TPM or cd to plugin dir and git pull"
fi
