#!/usr/bin/env bash
# TPM update hook — rebuilds the Zig binary when the plugin is updated.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$CURRENT_DIR" || exit 1

if command -v zig &>/dev/null; then
    zig build &>/dev/null
fi
