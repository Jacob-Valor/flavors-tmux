#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Bash / Rust output parity test harness
# ---------------------------------------------------------------------------
# Verifies that the Rust binary and Bash fallback scripts produce identical
# output. Run this from within a tmux session for full coverage.
#
# Usage:
#   cd /path/to/flavors-tmux
#   bash scripts/test-parity.sh
#
# Without tmux: only custom-number parity is tested.
# Within tmux:   theme colors, and other widgets are also tested.
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BIN="${PROJECT_DIR}/target/release/flavors_tmux"

# Auto-build if the binary is missing
if [[ ! -x "$BIN" ]]; then
    echo "Building Rust binary..."
    (cd "$PROJECT_DIR" && cargo build --release) || { echo "BUILD FAILED" >&2; exit 1; }
fi

PASS=0
FAIL=0
SKIP=0

check() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL: $label" >&2
        echo "    expected: '$expected'" >&2
        echo "    actual:   '$actual'" >&2
    fi
}

skip() {
    local label="$1"
    local reason="$2"
    SKIP=$((SKIP + 1))
    echo "  SKIP: $label ($reason)"
}

echo "=== flavors-tmux Bash/Rust Parity Tests ==="
echo ""

# ---------------------------------------------------------------------------
# Custom number parity (no tmux needed)
# ---------------------------------------------------------------------------
echo "--- custom-number ---"
for style in arabic fsquare hsquare dsquare super sub earabic hide; do
    for id in "0" "1" "9" "42" "123" "9876543210"; do
        rust_out="$("$BIN" custom-number "$id" "$style" 2>/dev/null)" || true
        bash_out="$(bash "${SCRIPT_DIR}/custom-number.sh" "$id" "$style" 2>/dev/null)" || true
        check "custom-number $id $style" "$rust_out" "$bash_out"
    done
done

# Test invalid format (both should return non-zero)
rust_fails=false
"$BIN" custom-number "42" "invalid" &>/dev/null || rust_fails=true
bash_fails=false
bash "${SCRIPT_DIR}/custom-number.sh" "42" "invalid" &>/dev/null || bash_fails=true
if $rust_fails && $bash_fails; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "  FAIL: custom-number 42 invalid (both should exit non-zero)" >&2
    echo "    rust: $( $rust_fails && echo 'fail ✓' || echo 'ok ✗ (exit 0)' )" >&2
    echo "    bash: $( $bash_fails && echo 'fail ✓' || echo 'ok ✗ (exit 0)' )" >&2
fi

# Test hide returns empty (Bash exits 0 with no output)
rust_hide="$("$BIN" custom-number "42" "hide" 2>/dev/null)" || true
bash_hide="$(bash "${SCRIPT_DIR}/custom-number.sh" "42" "hide" 2>/dev/null)" || true
check "custom-number 42 hide" "$rust_hide" "$bash_hide"

# ---------------------------------------------------------------------------
# Theme color parity (requires tmux)
# ---------------------------------------------------------------------------
if [[ -z "${TMUX:-}" ]]; then
    echo ""
    echo "--- theme colors ---"
    skip "theme color parity" "not in a tmux session — run 'tmux new-session -d && bash scripts/test-parity.sh' for full coverage"
else
    echo ""
    echo "--- theme colors ---"

    # All semantic color keys (matching the Theme struct fields)
    COLOR_KEYS=(
        background foreground surface surface_alt
        primary primary_bright on_primary on_primary_bright
        success success_bright danger danger_bright
        warning info info_bright accent accent_bright
        emphasis muted forge_github forge_gitlab forge_codeberg
    )

    # Ensure transparency is off for consistent background colors
    tmux set-option -g @flavors-tmux_transparent 0

    # Build the list of themes from the Rust binary
    mapfile -t themes < <("$BIN" theme-list 2>/dev/null)

    for theme in "${themes[@]}"; do
        tmux set-option -g @flavors-tmux_theme "$theme"

        for key in "${COLOR_KEYS[@]}"; do
            rust_val="$("$BIN" theme "$theme" "$key" 2>/dev/null)" || true
            # Source themes.sh in a subshell — it reads the tmux options we just set
            bash_val="$(bash -c "
                source '${SCRIPT_DIR}/themes.sh' 2>/dev/null
                echo \"\${THEME[$key]:-}\"
            ")" || true
            check "theme=$theme key=$key" "$rust_val" "$bash_val"
        done
    done

    # -----------------------------------------------------------------------
    # Theme list parity
    # -----------------------------------------------------------------------
    echo ""
    echo "--- theme-list ---"
    rust_list="$("$BIN" theme-list 2>/dev/null | sort)" || true
    bash_list="$(for t in "${themes[@]}"; do echo "$t"; done | sort)"
    check "theme-list identical" "$rust_list" "$bash_list"

    # -----------------------------------------------------------------------
    # CWD widget parity (requires tmux)
    # -----------------------------------------------------------------------
    echo ""
    echo "--- cwd ---"
    tmux set-option -g @flavors-tmux_theme hard
    tmux set-option -g @flavors-tmux_show_cwd 1

    rust_cwd="$("$BIN" cwd --theme hard /tmp 2>/dev/null)" || true
    bash_cwd="$(bash -c "
        tmux set-option -g @flavors-tmux_theme hard
        source '${SCRIPT_DIR}/themes.sh' 2>/dev/null
        RESET=\"#[fg=\${THEME[foreground]},bg=\${THEME[background]},nobold,noitalics,nounderscore,nodim]\"
        BASENAME=\$(basename /tmp)
        echo \"\${RESET}#[fg=\${THEME[emphasis]},bg=\${THEME[surface]},bold]󰉋 \${BASENAME}\"
    ")" || true
    check "cwd /tmp" "$rust_cwd" "$bash_cwd"

    # -----------------------------------------------------------------------
    # Git status widget parity (requires tmux + git repo)
    # -----------------------------------------------------------------------
    echo ""
    echo "--- git-status ---"
    if git rev-parse --git-dir &>/dev/null; then
        tmux set-option -g @flavors-tmux_theme hard
        tmux set-option -g @flavors-tmux_transparent 0

        rust_git="$("$BIN" git-status --theme hard . 2>/dev/null)" || true
        bash_git="$(bash "${SCRIPT_DIR}/git-status.sh" . 2>/dev/null | tr -d '\n')" || true
        check "git-status output" "$rust_git" "$bash_git"
    else
        skip "git-status output" "not in a git repository"
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Results ==="
echo "  passed: $PASS"
echo "  failed: $FAIL"
if [[ $SKIP -gt 0 ]]; then
    echo "  skipped: $SKIP"
fi

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "PARITY CHECK FAILED — $FAIL mismatches found."
    exit 1
fi

echo "All parity checks passed."
exit 0
