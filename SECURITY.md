# Security Policy

## Threat Model

flavors-tmux is a local tmux plugin — it reads configuration from tmux options
and environment variables, executes shell commands and a Rust binary for widget
rendering, and makes authenticated HTTP requests to forge APIs (GitHub, GitLab,
Codeberg). There is no network-facing service, no user authentication, and no
remote code execution surface.

The primary risk is **local privilege escalation**: a process or user with access
to the tmux socket or the ability to set tmux options could inject commands that
execute during status bar rendering. All option values that enter shell or tmux
format contexts are validated, escaped, or restricted to allowlisted patterns.

## Supported Versions

Only the latest commit on the `main` branch is actively maintained. Releases
are published to GitHub but receive no separate patch backports.

## Security Measures

| Measure | Location |
|---|---|
| Shell command options (`battery_name`, `forge_cache_ttl`) are `printf '%q'` escaped or regex-validated as digits-only before entering `#(...)` contexts | `flavors.tmux` |
| Theme colors are hardcoded in built-in themes or validated as `#[0-9A-Fa-f]{6}` in custom JSON themes | `scripts/themes.sh`, `src/core/theme_loader.rs` |
| `#` in user-supplied icon values is escaped to `##` to prevent tmux format injection | `flavors.tmux` |
| Forge tokens are read from environment variables only — tmux option storage is intentionally unsupported (CWE-522) | `src/widgets/wb_git_status.rs`, `scripts/wb-git-status.sh` |
| Token never appears in process command-line argv — written to a temp file and loaded via `curl -K` (CWE-214) | `src/widgets/wb_git_status.rs` |
| Auto-update verifies the remote URL matches `Jacob-Valor/flavors-tmux` before pulling (CWE-494) | `scripts/auto-update.sh` |
| Custom theme names are restricted to `^[A-Za-z0-9_-]+$` to prevent path traversal | `src/core/theme_loader.rs`, `scripts/themes.sh` |

## Reporting a Vulnerability

Open a [GitHub Issue](https://github.com/Jacob-Valor/flavors-tmux/issues) for
any security concern. For sensitive disclosures, reach out directly through the
repository owner's GitHub profile.
