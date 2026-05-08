# Gruvbox Tmux

![Overview](screenshots/overview.png)

A clean  Tmux theme that  follow the [gruvbox](https://github.com/morhetz/gruvbox) colors, Inspired by [Tokyo Night Tmux](https://github.com/janoamaral/tokyo-night-tmux).

## Requirements

This theme has the following hard requirements:

- Any font from [Nerd Fonts](https://www.nerdfonts.com/) 
- [Bash](https://www.gnu.org/software/bash/)

The following are recommended for full support of all widgets and features:

- bc (for git widgets)
- jq, gh, glab (for git forges widgets)

## Installation using TPM

In your `tmux.conf` add :

```bash
set -g @plugin "https://gitlab.com/motaz-shokry/gruvbox-tmux"
```

## Configuration

Add these lines to your  `.tmux.conf`:

### Theme Flavor

```bash
set -g @gruvbox-tmux_theme "medium"  # hard | medium | soft | light | tokyonight | catppuccin | dracula | nord
set -g @gruvbox-tmux_transparent 0   # 1 | 0
```

### Terminal icons

```bash
set -g @gruvbox-tmux_terminal_icon 
set -g @gruvbox-tmux_active_terminal_icon 
```

### Number styles


```bash
set -g @gruvbox-tmux_window_id_style hsquare  # hsquare | fsquare | sub | super | arabic | earabic
set -g @gruvbox-tmux_pane_id_style super      # hsquare | fsquare | sub | super | arabic | earabic
set -g @gruvbox-tmux_zoom_id_style dsquare    # hsquare | fsquare | sub | super | arabic | earabic
```

### Widgets

For widgets add following lines in you `.tmux.conf`

#### Time widget

This widget is enabled by default. To disable it:

```bash
set -g @gruvbox-tmux_show_datetime 0
```

Time options

```bash
set -g @gruvbox-tmux_time_format 12H
```
##### Available Options
- `24H`: 18:30
- `12H`: 6:30 PM

#### Battery Widget

```bash
set -g @gruvbox-tmux_show_battery_widget 1     # 0 to disable
set -g @gruvbox-tmux_battery_name "BAT0"       # run `ls /sys/class/power_supply` to know
set -g @gruvbox-tmux_battery_low_threshold 25 
```


### Snapshots

![Hard](screenshots/hard.png)
![Light](screenshots/light.png)
