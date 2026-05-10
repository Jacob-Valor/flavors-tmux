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

## Conventions
- All tmux options use prefix `@flavors-tmux_`
- Themes define colors by semantic meaning (success, danger, primary, etc.), not color names
- Requires a Nerd Font for icon rendering
- Zig module: `src/root.zig` is the library entrypoint, `src/main.zig` is the CLI entrypoint
