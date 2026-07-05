#!/usr/bin/env bash
# TPM install hook — builds the Rust binary when the plugin is first installed.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$CURRENT_DIR" || exit 1

if command -v cargo &>/dev/null; then
    cargo build --release &>/dev/null
else
    echo "flavors-tmux: cargo not found; using Bash fallbacks" >&2
fi
