use std::collections::hash_map::DefaultHasher;
use std::fmt::Write;
use std::fs;
use std::hash::{Hash, Hasher};
use std::path::Path;
use std::sync::OnceLock;

use crate::core::cache::{cache_base, read_fresh_cache, write_cache};
use crate::core::util::{parse_porcelain_v2, run_git_command, trim_branch_name, ParsedStatusV2};
use crate::core::widget::WidgetContext;
use crate::core::Theme;
use crate::tmux_renderer::ThemeHex;

/// Cached HOME so we don't syscall std::env::var("HOME") on every render.
fn home_hash() -> u64 {
    static HOME_HASH: OnceLock<u64> = OnceLock::new();
    *HOME_HASH.get_or_init(|| {
        let home = std::env::var("HOME").unwrap_or_default();
        let mut hasher = DefaultHasher::new();
        home.hash(&mut hasher);
        hasher.finish()
    })
}

enum SyncMode {
    Clean,
    Dirty,
    Ahead,
    Behind,
}

fn get_porcelain_v2_raw(repo_path: &str) -> String {
    let stdout = match run_git_command(
        &[
            "git",
            "--no-optional-locks",
            "status",
            "--porcelain=v2",
            "--branch",
            "--show-stash",
        ],
        Some(Path::new(repo_path)),
    ) {
        Ok(out) => out,
        Err(_) => match run_git_command(
            &[
                "git",
                "--no-optional-locks",
                "status",
                "--porcelain=v2",
                "--branch",
            ],
            Some(Path::new(repo_path)),
        ) {
            Ok(out) => out,
            Err(_) => return String::new(),
        },
    };

    String::from_utf8(stdout).unwrap_or_default()
}

// Same idea as the diff-stat cache below: a cache hit costs zero subprocess
// spawns. Branch name / ahead-behind / stash count can lag up to this TTL
// after a checkout, commit, fetch, or stash push — bounded and consistent
// with the tradeoff already accepted for diff stats.
const STATUS_CACHE_TTL_SECS: u64 = 2;

fn status_cache_path(repo_path: &str) -> String {
    let h = hash_path(repo_path);
    let uh = home_hash();
    format!("{}/flavors-tmux-porcelain-{uh:x}-{h:x}", cache_base())
}

/// Cache the parsed porcelain for a repo for the lifetime of one `status`
/// process. tmux may invoke the same widget twice per refresh (e.g. the
/// same repo path from two panes); without this each call re-spawns git.
/// The TTL check still applies on the disk cache, so staleness is bounded.
use std::cell::RefCell;

thread_local! {
    static PORCELAIN_CACHE: RefCell<Option<(String, ParsedStatusV2)>> = const { RefCell::new(None) };
}

fn get_porcelain_v2(repo_path: &str) -> ParsedStatusV2 {
    let cache_path = status_cache_path(repo_path);

    // In-process hit: same repo, already fetched this process lifetime.
    PORCELAIN_CACHE.with(|c| {
        let mut cache = c.borrow_mut();
        if let Some((path, parsed)) = cache.as_ref() {
            if path == repo_path {
                return parsed.clone();
            }
        }

        let parsed = if let Some(cached) = read_fresh_cache(&cache_path, STATUS_CACHE_TTL_SECS) {
            parse_porcelain_v2(&cached)
        } else {
            let stdout_str = get_porcelain_v2_raw(repo_path);
            write_cache(&cache_path, &stdout_str);
            parse_porcelain_v2(&stdout_str)
        };
        *cache = Some((repo_path.to_owned(), parsed.clone()));
        parsed
    })
}

fn get_diff_stats(repo_path: &str) -> (usize, usize) {
    let stdout = match run_git_command(
        &["git", "--no-optional-locks", "diff", "--numstat", "HEAD"],
        Some(Path::new(repo_path)),
    ) {
        Ok(out) => out,
        Err(_) => return (0, 0),
    };

    let text = String::from_utf8(stdout).unwrap_or_default();
    let mut insertions = 0usize;
    let mut deletions = 0usize;

    for line in text.lines() {
        let mut it = line.split('\t');
        let ins_str = it.next().unwrap_or("");
        let del_str = it.next().unwrap_or("");
        if ins_str.is_empty() || del_str.is_empty() {
            continue;
        }
        insertions += ins_str.parse::<usize>().unwrap_or(0);
        deletions += del_str.parse::<usize>().unwrap_or(0);
    }

    (insertions, deletions)
}

fn hash_path(path: &str) -> u64 {
    let mut hasher = DefaultHasher::new();
    path.hash(&mut hasher);
    hasher.finish()
}

fn diff_cache_path(repo_path: &str) -> String {
    let h = hash_path(repo_path);
    let uh = home_hash();
    format!("{}/flavors-tmux-diff-{uh:x}-{h:x}", cache_base())
}

// Short enough that edits to tracked files (or a new commit) during an
// active session show up within one or two statusline redraws, long enough
// that a cache hit costs zero subprocess spawns instead of one.
//
// The cache key is deliberately just the file's mtime age, not HEAD: reading
// HEAD used to cost its own `git rev-parse` spawn on every single render,
// even on a cache hit, which defeated half the point of caching. The
// tradeoff is that a commit landing inside the TTL window can show
// pre-commit insertion/deletion counts for up to DIFF_CACHE_TTL_SECS —
// bounded and imperceptible at this TTL, same tradeoff already accepted for
// working-tree edits.
const DIFF_CACHE_TTL_SECS: u64 = 3;

fn get_diff_stats_cached(repo_path: &str) -> (usize, usize) {
    let cache_path = diff_cache_path(repo_path);

    let cache_fresh = fs::metadata(&cache_path)
        .ok()
        .and_then(|meta| meta.modified().ok())
        .and_then(|mtime| mtime.elapsed().ok())
        .map(|age| age.as_secs() < DIFF_CACHE_TTL_SECS)
        .unwrap_or(false);

    if cache_fresh {
        if let Ok(content) = fs::read_to_string(&cache_path) {
            let mut parts = content.splitn(2, ' ');
            if let (Some(ins_str), Some(del_str)) = (parts.next(), parts.next()) {
                if let (Ok(ins), Ok(del)) = (ins_str.parse(), del_str.parse()) {
                    return (ins, del);
                }
            }
        }
    }
    let stats = get_diff_stats(repo_path);
    let tmp_path = format!("{cache_path}.tmp");
    let _ = fs::write(&tmp_path, format!("{} {}", stats.0, stats.1));
    let _ = fs::rename(&tmp_path, &cache_path);
    stats
}

/// Fetch + parse the porcelain status for `repo_path`, using the in-process
/// and on-disk caches. The `status` renderer calls this once per repo path
/// and shares the result with `run_with_theme_hex_prefetched`, so one
/// `git status` spawn serves the whole render instead of one per widget.
pub(crate) fn prefetch_porcelain(repo_path: &str) -> ParsedStatusV2 {
    get_porcelain_v2(repo_path)
}

/// Render the git status widget.
/// Shows sync icon + branch + changed/insertions/deletions/untracked/stash/conflicts/ahead/behind counts.
pub fn run(theme: Theme, repo_path: &str) -> String {
    let theme_hex = ThemeHex::from_theme(theme);
    let status = get_porcelain_v2(repo_path);
    run_with_theme_hex_prefetched(theme, &theme_hex, &status, repo_path)
}

/// Like `run_with_theme_hex`, but accepts a pre-parsed porcelain status so the
/// `status` renderer can share one `git status` spawn across widgets that run
/// in the same process for the same repo.
pub(crate) fn run_with_theme_hex_prefetched(
    theme: Theme,
    theme_hex: &ThemeHex,
    status: &ParsedStatusV2,
    repo_path: &str,
) -> String {
    let ctx = WidgetContext::from_theme_hex(theme, theme_hex);
    let theme = ctx.theme;

    let branch_raw = match status.branch.as_deref() {
        Some(b) if !b.is_empty() && b != "HEAD" => b,
        _ => return String::new(),
    };

    let display_branch = trim_branch_name(branch_raw);

    let untracked = status.untracked;
    let conflict_count = status.conflicts;
    let ahead = status.ahead;
    let behind = status.behind;
    let changed = status.changed;

    let sync_mode = if changed > 0 {
        SyncMode::Dirty
    } else if ahead > 0 {
        SyncMode::Ahead
    } else if behind > 0 {
        SyncMode::Behind
    } else {
        SyncMode::Clean
    };

    let (insertions, deletions) = if changed > 0 {
        get_diff_stats_cached(repo_path)
    } else {
        (0, 0)
    };
    let stash_count = status.stashes;

    let bg = theme_hex.color(theme.surface);
    let warning = theme_hex.color(theme.warning);
    let success = theme_hex.color(theme.success);
    let danger = theme_hex.color(theme.danger);
    let danger_bright = theme_hex.color(theme.danger_bright);
    let info_bright = theme_hex.color(theme.info_bright);
    let muted = theme_hex.color(theme.muted);

    let mut result = String::with_capacity(512);

    // Continuous surface block: one leading reset, then every sub-segment
    // (sync icon, branch, counts) paints on the same `surface` background.
    // No internal resets — those painted 1-cell `background` gaps between
    // sub-segments inside the block.
    result.push_str(ctx.reset.as_str());

    match sync_mode {
        SyncMode::Dirty => {
            let _ = write!(
                result,
                "#[bg={},fg={},bold]▒ 󱓎",
                bg, danger_bright
            );
        }
        SyncMode::Ahead => {
            let _ = write!(result, "#[bg={},fg={},bold]▒ 󰛃", bg, danger);
        }
        SyncMode::Behind => {
            let _ = write!(
                result,
                "#[bg={},fg={},bold]▒ 󰛀",
                bg, info_bright
            );
        }
        SyncMode::Clean => {
            let _ = write!(result, "#[bg={},fg={},bold]▒ ", bg, success);
        }
    }

    let _ = write!(
        result,
        " #[fg={},bg={},bold]{}",
        theme_hex.color(theme.foreground),
        bg,
        display_branch
    );

    if changed > 0 {
        let _ = write!(
            result,
            " #[fg={},bg={},bold] {}",
            warning, bg, changed
        );
    }

    if insertions > 0 {
        let _ = write!(
            result,
            " #[fg={},bg={},bold] {}",
            success, bg, insertions
        );
    }

    if deletions > 0 {
        let _ = write!(
            result,
            " #[fg={},bg={},bold] {}",
            danger, bg, deletions
        );
    }

    if untracked > 0 {
        let _ = write!(
            result,
            " #[fg={},bg={},bold] {}",
            muted, bg, untracked
        );
    }

    if stash_count > 0 {
        let _ = write!(
            result,
            " #[fg={},bg={},bold] {}",
            info_bright, bg, stash_count
        );
    }

    if conflict_count > 0 {
        let _ = write!(
            result,
            " #[fg={},bg={},bold]󰅘 {}",
            danger_bright, bg, conflict_count
        );
    }

    if ahead > 0 {
        let _ = write!(
            result,
            " #[fg={},bg={},bold]↑{}",
            info_bright, bg, ahead
        );
    }

    if behind > 0 {
        let _ = write!(
            result,
            " #[fg={},bg={},bold]↓{}",
            danger, bg, behind
        );
    }

    result.push(' ');
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::themes;

    #[test]
    fn git_status_produces_valid_tmux_output_in_project_repo() {
        let output = run(themes::hard::THEME, ".");
        if !output.is_empty() {
            assert!(output.contains("#[fg=") || output.contains("#[bg="));
            // The '▒' separator glyph precedes the sync icon.
            assert!(output.contains("▒"));
            assert!(output.ends_with(' '));
        }
    }
}
