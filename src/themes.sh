#!/usr/bin/env bash

# Theme loader with semantic color mapping.
# Themes define colors by *meaning* (success, danger, etc.) rather than
# literal names (green, red, etc.), so non-Gruvbox palettes render correctly.

SELECTED_THEME="$(tmux show-option -gv @gruvbox-tmux_theme 2>/dev/null || echo "hard")"
TRANSPARENT_THEME="$(tmux show-option -gv @gruvbox-tmux_transparent 2>/dev/null || echo 0)"

# ---------------------------------------------------------------------------
# Gruvbox palettes (original 4 variants)
# ---------------------------------------------------------------------------

declare -A THEMES=(
    # --- Gruvbox Hard ---
    [hard_background]="#1b1b1b"
    [hard_foreground]="#fbf1c7"
    [hard_surface]="#282828"
    [hard_surface_alt]="#1b1b1b"
    [hard_primary]="#458588"
    [hard_primary_bright]="#83a598"
    [hard_success]="#98971a"
    [hard_success_bright]="#b8bb26"
    [hard_danger]="#cc241d"
    [hard_danger_bright]="#fb4934"
    [hard_warning]="#d79921"
    [hard_warning_bright]="#fabd2f"
    [hard_info]="#689d6a"
    [hard_info_bright]="#8ec07c"
    [hard_accent]="#b16286"
    [hard_accent_bright]="#d3869b"
    [hard_emphasis]="#fbf1c7"
    [hard_muted]="#a89984"
    [hard_forge_github]="#fbf1c7"
    [hard_forge_gitlab]="#fc6d26"

    # --- Gruvbox Medium ---
    [medium_background]="#282828"
    [medium_foreground]="#fbf1c7"
    [medium_surface]="#32302F"
    [medium_surface_alt]="#282828"
    [medium_primary]="#458588"
    [medium_primary_bright]="#83a598"
    [medium_success]="#98971a"
    [medium_success_bright]="#b8bb26"
    [medium_danger]="#cc241d"
    [medium_danger_bright]="#fb4934"
    [medium_warning]="#d79921"
    [medium_warning_bright]="#fabd2f"
    [medium_info]="#689d6a"
    [medium_info_bright]="#8ec07c"
    [medium_accent]="#b16286"
    [medium_accent_bright]="#d3869b"
    [medium_emphasis]="#fbf1c7"
    [medium_muted]="#a89984"
    [medium_forge_github]="#fbf1c7"
    [medium_forge_gitlab]="#fc6d26"

    # --- Gruvbox Soft ---
    [soft_background]="#32302F"
    [soft_foreground]="#fbf1c7"
    [soft_surface]="#3C3836"
    [soft_surface_alt]="#32302F"
    [soft_primary]="#458588"
    [soft_primary_bright]="#83a598"
    [soft_success]="#98971a"
    [soft_success_bright]="#b8bb26"
    [soft_danger]="#cc241d"
    [soft_danger_bright]="#fb4934"
    [soft_warning]="#d79921"
    [soft_warning_bright]="#fabd2f"
    [soft_info]="#689d6a"
    [soft_info_bright]="#8ec07c"
    [soft_accent]="#b16286"
    [soft_accent_bright]="#d3869b"
    [soft_emphasis]="#fbf1c7"
    [soft_muted]="#a89984"
    [soft_forge_github]="#fbf1c7"
    [soft_forge_gitlab]="#fc6d26"

    # --- Gruvbox Light ---
    [light_background]="#F9F5D7"
    [light_foreground]="#1b1b1b"
    [light_surface]="#EBDBB2"
    [light_surface_alt]="#F9F5D7"
    [light_primary]="#458588"
    [light_primary_bright]="#076678"
    [light_success]="#98971a"
    [light_success_bright]="#79740E"
    [light_danger]="#cc241d"
    [light_danger_bright]="#9D0006"
    [light_warning]="#d79921"
    [light_warning_bright]="#B57614"
    [light_info]="#689d6a"
    [light_info_bright]="#427B58"
    [light_accent]="#b16286"
    [light_accent_bright]="#8F3F71"
    [light_emphasis]="#1b1b1b"
    [light_muted]="#7c6f64"
    [light_forge_github]="#1b1b1b"
    [light_forge_gitlab]="#fc6d26"

    # -----------------------------------------------------------------------
    # Tokyo Night
    # -----------------------------------------------------------------------
    [tokyonight_background]="#1a1b26"
    [tokyonight_foreground]="#a9b1d6"
    [tokyonight_surface]="#24283b"
    [tokyonight_surface_alt]="#1a1b26"
    [tokyonight_primary]="#7aa2f7"
    [tokyonight_primary_bright]="#bb9af7"
    [tokyonight_success]="#9ece6a"
    [tokyonight_success_bright]="#73daca"
    [tokyonight_danger]="#f7768e"
    [tokyonight_danger_bright]="#db4b4b"
    [tokyonight_warning]="#e0af68"
    [tokyonight_warning_bright]="#ff9e64"
    [tokyonight_info]="#7dcfff"
    [tokyonight_info_bright]="#b4f9f8"
    [tokyonight_accent]="#bb9af7"
    [tokyonight_accent_bright]="#d5a8e3"
    [tokyonight_emphasis]="#c0caf5"
    [tokyonight_muted]="#565f89"
    [tokyonight_forge_github]="#a9b1d6"
    [tokyonight_forge_gitlab]="#fc6d26"

    # -----------------------------------------------------------------------
    # Catppuccin Mocha
    # -----------------------------------------------------------------------
    [catppuccin_background]="#1e1e2e"
    [catppuccin_foreground]="#cdd6f4"
    [catppuccin_surface]="#313244"
    [catppuccin_surface_alt]="#1e1e2e"
    [catppuccin_primary]="#89b4fa"
    [catppuccin_primary_bright]="#b4befe"
    [catppuccin_success]="#a6e3a1"
    [catppuccin_success_bright]="#94e2d5"
    [catppuccin_danger]="#f38ba8"
    [catppuccin_danger_bright]="#eba0ac"
    [catppuccin_warning]="#fab387"
    [catppuccin_warning_bright]="#f9e2af"
    [catppuccin_info]="#89dceb"
    [catppuccin_info_bright]="#74c7ec"
    [catppuccin_accent]="#cba6f7"
    [catppuccin_accent_bright]="#f5c2e7"
    [catppuccin_emphasis]="#cdd6f4"
    [catppuccin_muted]="#6c7086"
    [catppuccin_forge_github]="#cdd6f4"
    [catppuccin_forge_gitlab]="#fc6d26"

    # -----------------------------------------------------------------------
    # Dracula
    # -----------------------------------------------------------------------
    [dracula_background]="#282a36"
    [dracula_foreground]="#f8f8f2"
    [dracula_surface]="#44475a"
    [dracula_surface_alt]="#282a36"
    [dracula_primary]="#8be9fd"
    [dracula_primary_bright]="#9aedfe"
    [dracula_success]="#50fa7b"
    [dracula_success_bright]="#69ff94"
    [dracula_danger]="#ff5555"
    [dracula_danger_bright]="#ff6e6e"
    [dracula_warning]="#f1fa8c"
    [dracula_warning_bright]="#ffffa5"
    [dracula_info]="#bd93f9"
    [dracula_info_bright]="#d6acff"
    [dracula_accent]="#ff79c6"
    [dracula_accent_bright]="#ff92df"
    [dracula_emphasis]="#f8f8f2"
    [dracula_muted]="#6272a4"
    [dracula_forge_github]="#f8f8f2"
    [dracula_forge_gitlab]="#fc6d26"

    # -----------------------------------------------------------------------
    # Nord
    # -----------------------------------------------------------------------
    [nord_background]="#2e3440"
    [nord_foreground]="#d8dee9"
    [nord_surface]="#3b4252"
    [nord_surface_alt]="#2e3440"
    [nord_primary]="#88c0d0"
    [nord_primary_bright]="#8fbcbb"
    [nord_success]="#a3be8c"
    [nord_success_bright]="#bf616a"
    [nord_danger]="#bf616a"
    [nord_danger_bright]="#d08770"
    [nord_warning]="#ebcb8b"
    [nord_warning_bright]="#e5e9f0"
    [nord_info]="#81a1c1"
    [nord_info_bright]="#5e81ac"
    [nord_accent]="#b48ead"
    [nord_accent_bright]="#c895bf"
    [nord_emphasis]="#eceff4"
    [nord_muted]="#4c566a"
    [nord_forge_github]="#d8dee9"
    [nord_forge_gitlab]="#fc6d26"
)

# ---------------------------------------------------------------------------
# Build the active theme array from semantic keys
# ---------------------------------------------------------------------------

declare -A THEME
for key in background foreground surface surface_alt \
           primary primary_bright \
           success success_bright \
           danger danger_bright \
           warning warning_bright \
           info info_bright \
           accent accent_bright \
           emphasis muted \
           forge_github forge_gitlab; do
    color_key="${SELECTED_THEME}_${key}"
    fallback_key="hard_${key}"
    THEME["$key"]="${THEMES[$color_key]:-${THEMES[$fallback_key]}}"
done

# ---------------------------------------------------------------------------
# Transparency override
# ---------------------------------------------------------------------------

if [[ "${TRANSPARENT_THEME}" == "1" ]]; then
    THEME["background"]="default"
fi

# ---------------------------------------------------------------------------
# Convenience reset string used by all widgets
# ---------------------------------------------------------------------------

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"
