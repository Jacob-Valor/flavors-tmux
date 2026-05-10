# flavors-tmux — agent instructions

## Build & test
- `zig build` — build debug binary → `zig-out/bin/flavors_tmux`
- `zig build test` — run all tests
- `zig build run` — run the binary
- CI: `zig build test` → `zig build` → verify `zig-out/bin/flavors_tmux` exists
- Zig 0.16.0 minimum, uses `std.Io` era APIs

## Dual Bash/Zig execution
- `flavors.tmux` auto-builds the Zig binary on first run if Zig is installed.
- Binary present → Zig CLI handles widgets (`src/widgets/*.zig`), else Bash fallback (`scripts/*.sh`).
- **Widget output format MUST match** between Zig and Bash implementations.

## Adding a theme
A new theme must be registered in **3 places**:
1. `src/themes/<name>.zig` — Zig theme definition + import/export in `src/themes/registry.zig`
2. `scripts/themes.sh` — Bash associative array entry in `load_theme()` case statement
3. `flavors.tmux:23` — `VALID_THEMES` array

## Color contrast requirements
- All foreground-on-background pairs must meet **WCAG AA** (≥4.5:1 for normal text, ≥3:1 for bold/large text)
- Run `/tmp/contrast.zig` (or build a similar checker) when modifying theme color values
- **`surface_alt` is always identical to `background`** in every theme — never use it as a text foreground; use `muted` for secondary text and `emphasis` for high-contrast text
- Light themes need **darker** foreground colors to pass contrast — test against the theme's specific background hex

## Color usage in widgets
Semantic colors used as text foregrounds and their backgrounds (update when adding/changing widgets):

| Field   | Used in                     | On background      |
|---------|-----------------------------|--------------------|
| success | battery 100%, git synced, wb PR/issue| `background` |
| danger  | battery low, git need-push, wb bug    | `background` |
| warning | battery mid, git changed, window last | `background` |
| info_bright | git need-pull                    | `background` |
| accent  | datetime separator (decorative only) | `surface_alt` / `background` |
| muted   | git untracked count, forge header   | `background` |
| emphasis | datetime time text               | `surface_alt` / `background` |
| forge_* | forge provider icon               | `background` |
| foreground | RESET, status text, window text | `background` |
| success_bright | window-status-current icon | `surface` |
| accent_bright  | window-status-current number | `surface` |

Unused colors: `info`, `warning_bright` — defined in every theme but not referenced by any widget.

## Conventions
- All tmux options use prefix `@flavors-tmux_`
- Themes define colors by semantic meaning (success, danger, primary, etc.), not color names
- Requires a Nerd Font for icon rendering
- Zig module: `src/root.zig` is the library entrypoint, `src/main.zig` is the CLI entrypoint
- All foreground color changes must be synced between Zig (`src/themes/*.zig`) and Bash (`scripts/themes.sh`)
