use std::collections::hash_map::DefaultHasher;
use std::fs;
use std::hash::{Hash, Hasher};
use std::path::Path;

use crate::core::cache::{cache_base, read_fresh_cache, write_cache};
use crate::core::util::{parse_porcelain_v2, run_git_command, trim_branch_name, ParsedStatusV2};
use crate::core::widget::WidgetContext;
use crate::core::Theme;
use crate::tmux_renderer::ThemeHex;

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
            "status",
            "--porcelain=v2",
            "--branch",
            "--show-stash",
        ],
        Some(Path::new(repo_path)),
    ) {
        Ok(out) => out,
        Err(_) => match run_git_command(
            &["git", "status", "--porcelain=v2", "--branch"],
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
    let user = std::env::var("HOME").unwrap_or_default();
    let uh = hash_path(&user);
    format!("{}/flavors-tmux-porcelain-{uh:x}-{h:x}", cache_base())
}

fn get_porcelain_v2(repo_path: &str) -> ParsedStatusV2 {
    let cache_path = status_cache_path(repo_path);

    if let Some(cached) = read_fresh_cache(&cache_path, STATUS_CACHE_TTL_SECS) {
        return parse_porcelain_v2(&cached);
    }

    let stdout_str = get_porcelain_v2_raw(repo_path);
    write_cache(&cache_path, &stdout_str);
    parse_porcelain_v2(&stdout_str)
}

fn get_diff_stats(repo_path: &str) -> (usize, usize) {
    let stdout = match run_git_command(
        &["git", "diff", "--numstat", "HEAD"],
        Some(Path::new(repo_path)),
    ) {
        Ok(out) => out,
        Err(_) => return (0, 0),
    };

    let text = String::from_utf8_lossy(&stdout);
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
    let user = std::env::var("HOME").unwrap_or_default();
    let uh = hash_path(&user);
    format!("/tmp/flavors-tmux-diff-{uh:x}-{h:x}")
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

/// Render the git status widget.
/// Shows sync icon + branch + changed/insertions/deletions/untracked/stash/conflicts/ahead/behind counts.
pub fn run(theme: Theme, repo_path: &str) -> String {
    let theme_hex = ThemeHex::from_theme(theme);
    run_with_theme_hex(theme, &theme_hex, repo_path)
}

pub(crate) fn run_with_theme_hex(theme: Theme, theme_hex: &ThemeHex, repo_path: &str) -> String {
    let ctx = WidgetContext::from_theme_hex(theme, theme_hex);
    let theme = ctx.theme;

    let status = get_porcelain_v2(repo_path);

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

    match sync_mode {
        SyncMode::Dirty => {
            result.push_str(&format!(
                "{}#[bg={},fg={},bold]▒ 󱓎",
                ctx.reset, bg, danger_bright
            ));
        }
        SyncMode::Ahead => {
            result.push_str(&format!("{}#[bg={},fg={},bold]▒ 󰛃", ctx.reset, bg, danger));
        }
        SyncMode::Behind => {
            result.push_str(&format!(
                "{}#[bg={},fg={},bold]▒ 󰛀",
                ctx.reset, bg, info_bright
            ));
        }
        SyncMode::Clean => {
            result.push_str(&format!("{}#[bg={},fg={},bold]▒ ", ctx.reset, bg, success));
        }
    }

    result.push_str(&format!(" {}{}", ctx.reset, display_branch));

    if changed > 0 {
        result.push_str(&format!(
            " {}#[fg={},bg={},bold] {}",
            ctx.reset, warning, bg, changed
        ));
    }

    if insertions > 0 {
        result.push_str(&format!(
            " {}#[fg={},bg={},bold] {}",
            ctx.reset, success, bg, insertions
        ));
    }

    if deletions > 0 {
        result.push_str(&format!(
            " {}#[fg={},bg={},bold] {}",
            ctx.reset, danger, bg, deletions
        ));
    }

    if untracked > 0 {
        result.push_str(&format!(
            " {}#[fg={},bg={},bold] {}",
            ctx.reset, muted, bg, untracked
        ));
    }

    if stash_count > 0 {
        result.push_str(&format!(
            " {}#[fg={},bg={},bold] {}",
            ctx.reset, info_bright, bg, stash_count
        ));
    }

    if conflict_count > 0 {
        result.push_str(&format!(
            " {}#[fg={},bg={},bold]󰅘 {}",
            ctx.reset, danger_bright, bg, conflict_count
        ));
    }

    if ahead > 0 {
        result.push_str(&format!(
            " {}#[fg={},bg={},bold]↑{}",
            ctx.reset, info_bright, bg, ahead
        ));
    }

    if behind > 0 {
        result.push_str(&format!(
            " {}#[fg={},bg={},bold]↓{}",
            ctx.reset, danger, bg, behind
        ));
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
            assert!(output.contains("▒"));
            assert!(output.ends_with(' '));
        }
    }
}
