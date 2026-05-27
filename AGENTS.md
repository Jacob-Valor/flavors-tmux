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

### Built-in theme (3 places)
1. `src/themes/<name>.zig` — Zig theme definition + import/export in `src/themes/registry.zig`
2. `scripts/themes.sh` — Bash associative array entry in `load_theme()` case statement
3. `flavors.tmux:23` — `VALID_THEMES` array

### Custom user theme (JSON, no code changes)
Create `~/.config/flavors-tmux/themes/<name>.json` with any subset of the 22 theme fields. Missing keys fall back to defaults. Zig `byName()` checks custom themes first; Bash `load_theme()` checks via `jq` if available. No registry edits needed.

## Color contrast requirements
- All foreground-on-background pairs must meet **WCAG AA** (≥4.5:1 for normal text, ≥3:1 for bold/large text)
- Run `/tmp/contrast.zig` (or build a similar checker) when modifying theme color values
- **`surface_alt` is always identical to `background`** in every theme — never use it as a text foreground; use `muted` for secondary text and `emphasis` for high-contrast text
- Light themes need **darker** foreground colors to pass contrast — test against the theme's specific background hex

## Color usage in widgets
Semantic colors used as text foregrounds and their backgrounds (update when adding/changing widgets):

| Field   | Used in                     | On background      |
|---------|-----------------------------|--------------------|
| success | battery 100%, git synced, wb PR/issue, CPU <50%, mem <50%, AI assistant active | `background` |
| danger  | battery low, git need-push, wb bug, CPU ≥80%, mem ≥80%    | `background` |
| danger_bright | git conflict count `󰅘`       | `background` |
| warning | battery mid, git changed, window last, hostname SSH, CPU 50-79%, mem 50-79% | `background` |
| info_bright | git need-pull, stash count ``, ahead `↑` | `background` |
| accent  | datetime separator (decorative only) | `surface_alt` / `background` |
| muted   | git untracked count ``, forge header , hostname local, docker context default | `background` |
| info     | kubernetes context (non-prod/non-staging), docker context (non-default) | `background` |
| emphasis | datetime time text               | `surface_alt` / `background` |
| forge_* | forge provider icon               | `background` |
| foreground | RESET, status text, window text | `background` |
| success_bright | window-status-current icon | `surface` |
| accent_bright  | window-status-current number | `surface` |

Unused colors: none — all defined colors are referenced by at least one widget.

## Conventions
- All tmux options use prefix `@flavors-tmux_`
- Themes define colors by semantic meaning (success, danger, primary, etc.), not color names
- Requires a Nerd Font for icon rendering
- Zig module: `src/root.zig` is the library entrypoint, `src/main.zig` is the CLI entrypoint
- All foreground color changes must be synced between Zig (`src/themes/*.zig`) and Bash (`scripts/themes.sh`)
