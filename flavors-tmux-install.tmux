#!/usr/bin/env bash
# TPM install hook — builds the Zig binary when the plugin is first installed.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$CURRENT_DIR" || exit 1

if command -v zig &>/dev/null; then
    zig build &>/dev/null
else
    echo "flavors-tmux: zig not found; using Bash fallbacks" >&2
fi
