use std::path::Path;

use crate::core::util::{parse_porcelain_v2, run_git_command, trim_branch_name, ParsedStatusV2};
use crate::core::widget::WidgetContext;
use crate::tmux_renderer;

enum SyncMode {
    Clean,
    Dirty,
    Ahead,
    Behind,
}

fn get_porcelain_v2(repo_path: &str) -> ParsedStatusV2 {
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
            Err(_) => return ParsedStatusV2::default(),
        },
    };

    let stdout_str = String::from_utf8(stdout).unwrap_or_default();
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

/// Render the git status widget.
/// Shows sync icon + branch + changed/insertions/deletions/untracked/stash/conflicts/ahead/behind counts.
pub fn run(theme_name: &str, transparent: bool, repo_path: &str) -> String {
    let ctx = WidgetContext::new(theme_name, transparent);
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
        get_diff_stats(repo_path)
    } else {
        (0, 0)
    };
    let stash_count = status.stashes;

    let bg = tmux_renderer::color_hex_string(theme.background);
    let warning = tmux_renderer::color_hex_string(theme.warning);
    let success = tmux_renderer::color_hex_string(theme.success);
    let danger = tmux_renderer::color_hex_string(theme.danger);
    let danger_bright = tmux_renderer::color_hex_string(theme.danger_bright);
    let info_bright = tmux_renderer::color_hex_string(theme.info_bright);
    let muted = tmux_renderer::color_hex_string(theme.muted);

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

    #[test]
    fn git_status_produces_valid_tmux_output_in_project_repo() {
        let output = run("hard", false, ".");
        if !output.is_empty() {
            assert!(output.contains("#[fg=") || output.contains("#[bg="));
            assert!(output.contains("▒"));
            assert!(output.ends_with(' '));
        }
    }
}
