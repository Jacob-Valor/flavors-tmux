# Flavors Tmux

![Flavors Tmux overview](screenshots/overview.png)

**Flavors Tmux** is a clean, multi-palette tmux theme with Nerd Font icons,
semantic colors, and optional status widgets for Git, GitHub/GitLab, battery,
Docker, Kubernetes, and more.

It started from a Gruvbox-inspired style and now includes several familiar
flavors: Gruvbox Hard, Medium, Soft, Light, Tokyo Night, Catppuccin, Dracula,
Nord, GitHub Dark, One Dark, Solarized Dark, Solarized Light, Monokai,
Monokai Nebula, GitHub Light, Ayu Dark, Ayu Light, Flexoki Dark, Flexoki Light,
Rose Pine, Rose Pine Dawn, Everforest, and Kanagawa.

## Features

- **Built-in themes** — Twenty-three color flavors plus user-defined custom themes via JSON
- **Git status** — Branch, change, insert, delete, untracked, stash, conflict, ahead/behind, push, and pull indicators
- **Forge widget** — Optional GitHub, GitLab, and Codeberg pull requests, reviews, issues, and bugs
- **Time** — Configurable 12-hour, 24-hour, or hidden
- **Battery** — Optional widget with charging/discharging icons
- **Hostname / SSH** — Optional local and SSH session indicator
- **CPU & memory** — Optional widget with color-coded thresholds
- **Kubernetes** — Optional context and namespace widget with environment color-coding
- **Current working directory** — Optional widget with Git repo-relative paths
- **Terraform workspace** — Optional widget
- **Docker context** — Optional widget
- **GPG/SSH agent** — Optional status widget
- **YADM dotfiles** — Optional status widget
- **Number styles** — Custom window, pane, and zoom number styles (arabic, superscript, etc.)
- **Terminal icons** — Custom terminal and active-terminal icons
- **Transparent bar** — Optional transparent status bar background

## Requirements

Required:

- [tmux](https://github.com/tmux/tmux)
- [Bash](https://www.gnu.org/software/bash/)
- A [Nerd Font](https://www.nerdfonts.com/) for icon rendering

Recommended for full widget support:

- `git`
- `gh`, `glab`, or `curl` for forge status widgets
- `jq` for forge status widgets when using the Bash fallback

Optional:

- [Rust](https://www.rust-lang.org/) / Cargo — builds a native binary for faster
  widgets (auto-detected by TPM and manual install)

## Installation

### TPM

Add the plugin to your `.tmux.conf`:

```tmux
set -g @plugin "Jacob-Valor/flavors-tmux"
```

Then press your TPM prefix followed by `I` to install.

> **Note:** If [Rust/Cargo](https://www.rust-lang.org/) is installed, TPM will automatically
> build the native binary on install and update for faster widget rendering.
> Without Cargo, the plugin falls back to Bash scripts.

### Manual

Clone the repository and run the plugin from your `.tmux.conf`:

```sh
git clone https://github.com/Jacob-Valor/flavors-tmux ~/.tmux/plugins/flavors-tmux
```

```tmux
run-shell ~/.tmux/plugins/flavors-tmux/flavors.tmux
```

Reload tmux after installing:

```sh
tmux source-file ~/.tmux.conf
```

## Configuration

All options use the `@flavors-tmux_` prefix.

### Theme

```tmux
set -g @flavors-tmux_theme "hard"
set -g @flavors-tmux_transparent 0
```

Available themes:

- `hard`
- `medium`
- `soft`
- `light`
- `tokyonight`
- `catppuccin`
- `dracula`
- `nord`
- `github_dark`
- `onedark`
- `solarized_dark`
- `solarized_light`
- `monokai`
- `monokai_nebula`
- `github_light`
- `ayu_dark`
- `ayu_light`
- `flexoki_dark`
- `flexoki_light`
- `rose_pine`
- `rose_pine_dawn`
- `everforest`
- `kanagawa`

Set `@flavors-tmux_transparent` to `1` to use your terminal background.

### Custom themes

Create a JSON file at `~/.config/flavors-tmux/themes/<name>.json` to define your own palette:

```json
{
  "background": "#0d1117",
  "foreground": "#c9d1d9",
  "surface": "#161b22",
  "surface_alt": "#0d1117",
  "primary": "#58a6ff",
  "primary_bright": "#79b8ff",
  "on_primary": "#000000",
  "on_primary_bright": "#000000",
  "success": "#3fb950",
  "success_bright": "#56d364",
  "danger": "#f85149",
  "danger_bright": "#ff7b72",
  "warning": "#d29922",
  "warning_bright": "#e3b341",
  "info": "#58a6ff",
  "info_bright": "#79b8ff",
  "accent": "#a371f7",
  "accent_bright": "#bc8cff",
  "emphasis": "#e6edf3",
  "muted": "#8b949e",
  "forge_github": "#ffffff",
  "forge_gitlab": "#fc6d26",
  "forge_codeberg": "#fc6d26"
}
```

Then reference it by name:

```tmux
set -g @flavors-tmux_theme "mytheme"
```

Custom themes take precedence over built-in themes. All fields are optional — missing keys fall back to sensible defaults. If `jq` is available, Bash fallback scripts can also load custom themes.

### Icons

```tmux
set -g @flavors-tmux_terminal_icon ""
set -g @flavors-tmux_active_terminal_icon ""
```

> **Security note:** `#` characters in icon values are automatically escaped to
> `##` to prevent tmux format injection (`#(command)` execution). This is
> transparent — use `#` as you normally would in Nerd Font icon names.

### Number styles

```tmux
set -g @flavors-tmux_window_id_style "hsquare"
set -g @flavors-tmux_pane_id_style "super"
set -g @flavors-tmux_zoom_id_style "dsquare"
```

Available styles:

- `arabic` — `0 1 2 3`
- `earabic` — Eastern Arabic numerals
- `fsquare` — filled square icons
- `hsquare` — hollow square icons
- `dsquare` — double square icons
- `super` — superscript numbers
- `sub` — subscript numbers
- `hide` — hide the number

## Widgets

### Time

The time widget is enabled by default.

```tmux
set -g @flavors-tmux_show_time 1
set -g @flavors-tmux_time_format "24H"
```

Available formats:

- `24H` — `18:30`
- `12H` — `06:30 PM`
- `hide` — hide only the time text

Disable the whole time widget:

```tmux
set -g @flavors-tmux_show_time 0
```

### Git

The Git widget is enabled by default and appears inside Git repositories.

```tmux
set -g @flavors-tmux_show_git 1
```

Disable it:

```tmux
set -g @flavors-tmux_show_git 0
```

Indicators shown:

- Branch name (truncated to 25 chars)
- Changed file count ``
- Insertion count ``
- Deletion count ``
- Untracked file count ``
- Stash count ``
- Merge conflict count `󰅘`
- Ahead/behind upstream counts `↑` / `↓`
- Sync status icon: synced ``, changed `󱓎`, need-push `󰛃`, need-pull `󰛀`

### Forge (GitHub / GitLab / Codeberg)

The forge widget is enabled by default when the current repository uses GitHub,
GitLab, or Codeberg and the required CLI/token is available.

```tmux
set -g @flavors-tmux_show_wbg 1
```

Disable it:

```tmux
set -g @flavors-tmux_show_wbg 0
```

#### Codeberg

For Codeberg support, set a personal access token via environment variable:

```sh
export FLAVORS_TMUX_CODEBERG_TOKEN="your-token-here"
```

The plugin also checks `CODEBERG_TOKEN` as a fallback. Tmux option storage (`@flavors-tmux_codeberg_token`) is intentionally **not supported** — tmux global options are world-readable by any process with access to the tmux socket.

Generate a token at: https://codeberg.org/user/settings/applications

### Hostname / SSH

The hostname widget is disabled by default. It shows your system hostname, changing color and icon when connected via SSH.

```tmux
set -g @flavors-tmux_show_hostname 1
```

- Local session: `󰌽 hostname` in muted color
- SSH session: `󰣀 hostname` in warning color

### CPU and Memory

The CPU and memory widget is disabled by default. It shows live CPU and memory usage percentages with color-coded thresholds.

```tmux
set -g @flavors-tmux_show_cpu_memory 1
```

Color thresholds:

- **Green** (`success`) — below 50%
- **Yellow** (`warning`) — 50% to 79%
- **Red** (`danger`) — 80% and above

Works on Linux (`/proc/stat`, `/proc/meminfo`) and macOS (`top`, `vm_stat`).

### Battery

The battery widget is disabled by default.

```tmux
set -g @flavors-tmux_show_battery_widget 1
set -g @flavors-tmux_battery_name "BAT0"
set -g @flavors-tmux_battery_low_threshold 20
```

On Linux, run this to find your battery name:

```sh
ls /sys/class/power_supply
```

### Current Working Directory

Shows the current working directory. When inside a Git repository, displays `repo-name/current-dir`.

```tmux
set -g @flavors-tmux_show_cwd 1
```

### Kubernetes Context

Shows the active Kubernetes context and namespace. Automatically color-codes by environment:

- **Red** (`danger`) — production contexts
- **Yellow** (`warning`) — staging/development contexts
- **Cyan** (`info`) — all other contexts

```tmux
set -g @flavors-tmux_show_kubernetes 1
```

Requires `kubectl` to be installed and configured.

### Terraform Workspace

Shows the active Terraform workspace for the current directory.

```tmux
set -g @flavors-tmux_show_terraform 1
```

Requires `terraform` to be installed. The `default` workspace is shown in muted color; all others use the primary color.

### Docker Context

Shows the active Docker context.

```tmux
set -g @flavors-tmux_show_docker 1
```

Requires `docker` to be installed. The `default` context is shown in muted color; all others use the info color.

### YADM Dotfiles

Shows YADM dotfiles status when inside a YADM-managed repository.

```tmux
set -g @flavors-tmux_show_yadm 1
```

Requires `yadm` to be installed. Shows changed and untracked counts similar to the Git widget.

### Auto-update

Check for plugin updates automatically. Disabled by default.

```tmux
set -g @flavors-tmux_auto_update 1
set -g @flavors-tmux_auto_update_interval 24
```

Options:

- `@flavors-tmux_auto_update` — `1` to enable checking, `0` to disable (default)
- `@flavors-tmux_auto_update_interval` — hours between checks (default: `24`)
- `@flavors-tmux_auto_update_pull` — `1` to auto-pull updates silently (default: `0`, only notifies)
- `@flavors-tmux_auto_update_branch` — branch to track (default: `main`)

> **Security note:** Auto-pull only proceeds after verifying the remote URL
> matches the expected `Jacob-Valor/flavors-tmux` repository, preventing
> compromised or swapped remotes from injecting malicious code.

## Screenshots

### Gruvbox Hard

![Gruvbox Hard screenshot](screenshots/hard.png)

### Gruvbox Light

![Gruvbox Light screenshot](screenshots/light.png)

## Inspiration

- [Gruvbox](https://github.com/morhetz/gruvbox)
- [Tokyo Night Tmux](https://github.com/janoamaral/tokyo-night-tmux)
