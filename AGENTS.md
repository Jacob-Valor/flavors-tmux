# flavors-tmux — agent instructions

## Build & test
- `cargo build` — build debug binary → `target/debug/flavors_tmux`
- `cargo build --release` — build release binary → `target/release/flavors_tmux`
- `cargo test` — run all tests
- `cargo run` — run the binary
- `cargo run --bin codegen -- .` — regenerate Bash theme case block and VALID_THEMES
- CI: `cargo test` → `cargo build --release` → verify `target/release/flavors_tmux` exists
- Rust edition 2021, uses serde + serde_json for custom theme JSON

## Dual Bash/Rust execution
- `flavors.tmux` auto-builds the Rust binary on first run if Cargo is installed.
- Binary present → Rust CLI handles widgets (`src/widgets/*.rs`), else Bash fallback (`scripts/*.sh`).
- **Widget output format MUST match** between Rust and Bash implementations.

## Adding a theme

### Built-in theme (2 places + run codegen)
1. `src/themes/<name>.rs` — Rust theme definition + import/export in `src/themes/registry.rs`
2. Run `cargo run --bin codegen -- .` — auto-generates Bash case block in `scripts/themes.sh` and `VALID_THEMES` in `flavors.tmux`

### Custom user theme (JSON, no code changes)
Create `~/.config/flavors-tmux/themes/<name>.json` with any subset of the 22 theme fields. Missing keys fall back to defaults. Rust `by_name()` checks custom themes first; Bash `load_theme()` checks via `jq` if available. No registry edits needed.

## Color contrast requirements
- All foreground-on-background pairs must meet **WCAG AA** (≥4.5:1 for normal text, ≥3:1 for bold/large text)
- Run a contrast checker when modifying theme color values
- **`surface_alt` is always identical to `background`** in every theme — never use it as a text foreground; use `muted` for secondary text and `emphasis` for high-contrast text
- Light themes need **darker** foreground colors to pass contrast — test against the theme's specific background hex

## Color usage in widgets
Semantic colors used as text foregrounds and their backgrounds (update when adding/changing widgets):

| Field   | Used in                     | On background      |
|---------|-----------------------------|--------------------|
| success | battery 100%, git synced, wb PR/issue, CPU <50%, mem <50% | `background` |
| danger  | battery low, git need-push, wb bug, CPU ≥80%, mem ≥80%    | `background` |
| danger_bright | git conflict count `󰅘`       | `background` |
| warning | battery mid, git changed, CPU 50-79%, mem 50-79% | `background` |
| info_bright | git need-pull, stash count ``, ahead `↑` | `background` |
| accent  | datetime separator (decorative only), wb-git header | `surface_alt` / `background` |
| muted   | git untracked count ``, wb-git header icon | `background` |
| info     | kubernetes context (non-prod/non-staging) | `background` |
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
- Rust module: `src/lib.rs` is the library entrypoint, `src/main.rs` is the CLI entrypoint
- All foreground color changes must be synced between Rust (`src/themes/*.rs`) and Bash (`scripts/themes.sh`)
