#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Bash / Zig output parity test harness
# ---------------------------------------------------------------------------
# Verifies that the Zig binary and Bash fallback scripts produce identical
# output. Run this from within a tmux session for full coverage.
#
# Usage:
#   cd /path/to/flavors-tmux
#   bash scripts/test-parity.sh
#
# Without tmux: only custom-number parity is tested.
# Within tmux:   theme colors, hostname, and other widgets are also tested.
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ZIG_BIN="${PROJECT_DIR}/zig-out/bin/flavors_tmux"

# Auto-build if the binary is missing
if [[ ! -x "$ZIG_BIN" ]]; then
    echo "Building Zig binary..."
    (cd "$PROJECT_DIR" && zig build) || { echo "BUILD FAILED" >&2; exit 1; }
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

echo "=== flavors-tmux Bash/Zig Parity Tests ==="
echo ""

# ---------------------------------------------------------------------------
# Custom number parity (no tmux needed)
# ---------------------------------------------------------------------------
echo "--- custom-number ---"
for style in arabic fsquare hsquare dsquare super sub earabic hide; do
    for id in "0" "1" "9" "42" "123" "9876543210"; do
        zig_out="$("$ZIG_BIN" custom-number "$id" "$style" 2>/dev/null)" || true
        bash_out="$(bash "${SCRIPT_DIR}/custom-number.sh" "$id" "$style" 2>/dev/null)" || true
        check "custom-number $id $style" "$zig_out" "$bash_out"
    done
done

# Test invalid format (both should return non-zero)
if "$ZIG_BIN" custom-number "42" "invalid" &>/dev/null; then
    check "custom-number 42 invalid (zig should fail)" "non-zero" "zero"
else
    bash "${SCRIPT_DIR}/custom-number.sh" "42" "invalid" &>/dev/null || true
    # Bash version prints to stderr and exits 1; Zig exits non-zero
    check "custom-number 42 invalid returns error" "error" "error"
fi

# Test hide returns empty (Bash exits 0 with no output)
zig_hide="$("$ZIG_BIN" custom-number "42" "hide" 2>/dev/null)" || true
bash_hide="$(bash "${SCRIPT_DIR}/custom-number.sh" "42" "hide" 2>/dev/null)" || true
check "custom-number 42 hide" "$zig_hide" "$bash_hide"

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

    # Build the list of themes from the Zig binary
    mapfile -t themes < <("$ZIG_BIN" theme-list 2>/dev/null)

    for theme in "${themes[@]}"; do
        tmux set-option -g @flavors-tmux_theme "$theme"

        for key in "${COLOR_KEYS[@]}"; do
            zig_val="$("$ZIG_BIN" theme "$theme" "$key" 2>/dev/null)" || true
            # Source themes.sh in a subshell — it reads the tmux options we just set
            bash_val="$(bash -c "
                source '${SCRIPT_DIR}/themes.sh' 2>/dev/null
                echo \"\${THEME[$key]:-}\"
            ")" || true
            check "theme=$theme key=$key" "$zig_val" "$bash_val"
        done
    done

    # -----------------------------------------------------------------------
    # Theme list parity
    # -----------------------------------------------------------------------
    echo ""
    echo "--- theme-list ---"
    zig_list="$("$ZIG_BIN" theme-list 2>/dev/null | sort)" || true
    bash_list="$(for t in "${themes[@]}"; do echo "$t"; done | sort)"
    check "theme-list identical" "$zig_list" "$bash_list"

    # -----------------------------------------------------------------------
    # Hostname widget parity
    # -----------------------------------------------------------------------
    echo ""
    echo "--- hostname ---"
    # Unset SSH vars to test local hostname path
    saved_ssh="${SSH_CONNECTION:-}"
    saved_client="${SSH_CLIENT:-}"
    unset SSH_CONNECTION SSH_CLIENT

    zig_host="$("$ZIG_BIN" hostname --theme hard 2>/dev/null)" || true
    bash_host="$(bash -c "
        tmux set-option -g @flavors-tmux_theme hard
        source '${SCRIPT_DIR}/themes.sh' 2>/dev/null
        RESET=\"#[fg=\${THEME[foreground]},bg=\${THEME[background]},nobold,noitalics,nounderscore,nodim]\"
        HOSTNAME=\$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown)
        echo \"\${RESET}#[fg=\${THEME[muted]},bg=\${THEME[background]},bold]▒ 󰌽 \${HOSTNAME}\"
    ")" || true
    check "hostname local" "$zig_host" "$bash_host"

    # Restore SSH vars
    export SSH_CONNECTION="$saved_ssh"
    export SSH_CLIENT="$saved_client"

    # -----------------------------------------------------------------------
    # CWD widget parity (requires tmux)
    # -----------------------------------------------------------------------
    echo ""
    echo "--- cwd ---"
    tmux set-option -g @flavors-tmux_theme hard
    tmux set-option -g @flavors-tmux_show_cwd 1

    zig_cwd="$("$ZIG_BIN" cwd --theme hard /tmp 2>/dev/null)" || true
    bash_cwd="$(bash -c "
        tmux set-option -g @flavors-tmux_theme hard
        source '${SCRIPT_DIR}/themes.sh' 2>/dev/null
        RESET=\"#[fg=\${THEME[foreground]},bg=\${THEME[background]},nobold,noitalics,nounderscore,nodim]\"
        BASENAME=\$(basename /tmp)
        echo \"\${RESET}#[fg=\${THEME[emphasis]},bg=\${THEME[background]},bold]󰉋 \${BASENAME}\"
    ")" || true
    check "cwd /tmp" "$zig_cwd" "$bash_cwd"

    # -----------------------------------------------------------------------
    # Git status widget parity (requires tmux + git repo)
    # -----------------------------------------------------------------------
    echo ""
    echo "--- git-status ---"
    if git rev-parse --git-dir &>/dev/null; then
        tmux set-option -g @flavors-tmux_theme hard
        tmux set-option -g @flavors-tmux_transparent 0

        zig_git="$("$ZIG_BIN" git-status --theme hard . 2>/dev/null)" || true
        bash_git="$(bash "${SCRIPT_DIR}/git-status.sh" . 2>/dev/null | tr -d '\n')" || true
        check "git-status output" "$zig_git" "$bash_git"
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
