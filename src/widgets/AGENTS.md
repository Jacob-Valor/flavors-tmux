# src/widgets — agent instructions

## Widget architecture
Each widget is a self-contained Zig module under `src/widgets/` with:
- A `pub fn run(...)` as the single entrypoint
- Internal helper functions for subprocess spawning and data parsing
- A matching Bash script in `scripts/<name>.sh` for fallback parity

## Adding a widget

### Zig implementation (required)
1. Create `src/widgets/<name>.zig` with `pub fn run(allocator, io, theme_name, transparent, environ_map, writer, ...) !void`
2. Import in `src/main.zig` and add to the CLI dispatcher
3. Import in `src/root.zig` for library consumers
4. Use `themes.byName()` + `.withTransparentBackground()` for theme resolution
5. Prepend a leading `RESET` string before outputting colored segments

### Bash fallback (required)
1. Create `scripts/<name>.sh` that sources `themes.sh` and produces identical output
2. Add toggle check: `tmux show-option -gv @flavors-tmux_show_<name>`
3. Wire into `flavors.tmux` in both the Zig-binary and Bash-fallback branches

## Subprocess patterns
- Use `std.process.run()` for external commands (`git`, `kubectl`, `docker`, etc.)
- Use `util.runGitCommand()` (in `src/core/util.zig`) for git-specific calls
- Always handle errors gracefully: catch failures and return early or emit empty output
- Platform-specific paths: use `builtin.os.tag` to branch between Linux and macOS implementations

## Output format
- Widgets emit raw tmux format strings (e.g., `#[fg=#cc241d,bg=#1b1b1b,bold]...`)
- **Must prepend `RESET`** (`#[fg=<foreground>,bg=<background>,nobold,noitalics,nounderscore,nodim]`) before the first colored segment
- Use semantic color names from the theme struct (`theme.danger`, `theme.success`, etc.)
- Never hardcode color hex values

## Performance
- Minimize subprocess calls per render cycle
- Batch git operations where possible (see `git_status.zig` using `git status --porcelain=v2`)
- Only `wb_git_status.zig` has disk caching (TTL-based); other widgets run on every tmux status refresh

## Platform support
- Battery: Linux (`/sys/class/power_supply`), macOS (`pmset`)
- CPU/memory: Linux (`/proc/stat`, `/proc/meminfo`), macOS (`top`, `vm_stat`)
- Git widgets work on any platform with `git` installed
