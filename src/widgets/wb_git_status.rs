use std::collections::hash_map::DefaultHasher;
use std::env;
use std::fs;
use std::hash::Hasher;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use std::process::Command;
use std::sync::atomic::{AtomicU64, Ordering};
use std::thread;

use crate::core::cache::{cache_base, read_fresh_cache, write_cache};
use crate::core::util::run_git_command;
use crate::core::widget::WidgetContext;
use crate::core::{Color, Theme};
use crate::tmux_renderer::ThemeHex;

fn get_remote_url(repo_path: &str) -> Option<String> {
    let remote_stdout = run_git_command(&["git", "remote"], Some(Path::new(repo_path))).ok()?;
    let stdout = String::from_utf8_lossy(&remote_stdout);
    let trimmed = stdout.trim();
    if trimmed.is_empty() {
        return None;
    }
    let first_remote = trimmed.lines().next()?;
    if first_remote.is_empty() {
        return None;
    }

    let config_key = format!("remote.{}.url", first_remote);
    let url_stdout =
        run_git_command(&["git", "config", &config_key], Some(Path::new(repo_path))).ok()?;
    let url = String::from_utf8_lossy(&url_stdout).trim().to_owned();
    if url.is_empty() {
        None
    } else {
        Some(url)
    }
}

fn provider_from_url(url: &str) -> Option<String> {
    if let Some(rest) = url.strip_prefix("git@") {
        let colon_idx = rest.find(':')?;
        return Some(rest[..colon_idx].to_owned());
    }
    if let Some(rest) = url.strip_prefix("https://") {
        let slash_idx = rest.find('/')?;
        return Some(rest[..slash_idx].to_owned());
    }
    None
}

fn get_head_hash(repo_path: &str) -> Option<String> {
    let stdout = run_git_command(&["git", "rev-parse", "HEAD"], Some(Path::new(repo_path))).ok()?;
    let trimmed = String::from_utf8_lossy(&stdout).trim().to_owned();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed)
    }
}

fn cache_path(repo_path: &str, remote_url: &str, head_hash: Option<&str>) -> String {
    let mut hasher = DefaultHasher::new();
    hasher.write(repo_path.as_bytes());
    hasher.write(b"\x00");
    hasher.write(remote_url.as_bytes());
    hasher.write(b"\x00");
    if let Some(h) = head_hash {
        hasher.write(h.as_bytes());
    }
    let key = hasher.finish();

    format!("{}/flavors-tmux-wb-{:x}.cache", cache_base(), key)
}

fn run_gh_command(argv: &[&str], repo_path: &str) -> Result<String, ()> {
    let output = Command::new(argv[0])
        .args(&argv[1..])
        .current_dir(repo_path)
        .output()
        .map_err(|_| ())?;
    if !output.status.success() {
        return Err(());
    }
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}

fn command_exists(name: &str) -> bool {
    if let Some(path) = env::var_os("PATH") {
        for dir in env::split_paths(&path) {
            if dir.as_os_str().is_empty() {
                continue;
            }
            let candidate = dir.join(name);
            if candidate.is_file() {
                return true;
            }
        }
    }
    false
}

fn get_codeberg_token() -> Option<String> {
    for var in &["FLAVORS_TMUX_CODEBERG_TOKEN", "CODEBERG_TOKEN"] {
        if let Some(token) = env::var(var).ok().filter(|t| !t.trim().is_empty()) {
            return Some(token.trim().to_owned());
        }
    }
    None
}

fn is_valid_token(token: &str) -> bool {
    token.bytes().all(|c| (0x20..=0x7E).contains(&c))
}

fn parse_codeberg_owner_repo(remote_url: &str) -> Option<String> {
    let start = if let Some(rest) = remote_url.strip_prefix("git@codeberg.org:") {
        rest
    } else {
        remote_url.strip_prefix("https://codeberg.org/")?
    };

    let end = if remote_url.ends_with(".git") {
        remote_url.len() - 4
    } else {
        remote_url.len()
    };

    let start_idx = remote_url.len() - start.len();
    if start_idx >= end {
        return None;
    }
    Some(remote_url[start_idx..end].to_owned())
}

fn count_json_array_items(json_str: &str) -> usize {
    serde_json::from_str::<serde_json::Value>(json_str)
        .ok()
        .and_then(|v| v.as_array().map(|arr| arr.len()))
        .unwrap_or(0)
}

fn count_lines_matching(text: &str, prefix: &str) -> usize {
    text.lines().filter(|line| line.starts_with(prefix)).count()
}

fn append_segment(
    result: &mut String,
    theme_hex: &ThemeHex,
    color: Color,
    bg: &str,
    icon: &str,
    count: usize,
    _reset: &str,
) {
    if count == 0 {
        return;
    }
    use std::fmt::Write;
    let _ = write!(
        result,
        "#[fg={},bg={},bold]{} {} ",
        theme_hex.color(color),
        bg,
        icon,
        count,
    );
}

/// Run curl with a token passed via temp config file (not argv) to avoid
/// exposing the token in /proc/*/cmdline to other local users.
/// Uses a restricted temp directory (0700) so that on crash the token
/// file is not readable by other users — the kernel removes anonymous
/// O_TMPFILE inodes on fd close, while a 0700 directory prevents
/// cross-user access even if cleanup is skipped.
fn fetch_with_token(url: &str, token: &str, repo_path: &str) -> String {
    static TMP_COUNTER: AtomicU64 = AtomicU64::new(0);
    let id = TMP_COUNTER.fetch_add(1, Ordering::Relaxed);
    let dir = format!("/tmp/flavors-tmux-curl-{id:x}");

    // Create a temp directory with 0700 perms — crash-safe on multi-user
    // systems because other users cannot traverse into it.
    if fs::create_dir_all(&dir).is_err() {
        return String::new();
    }
    let _ = fs::set_permissions(&dir, std::fs::Permissions::from_mode(0o700));

    let config_path = format!("{dir}/curl.conf");
    let config_content = format!("header = \"Authorization: token {}\"\n", token);

    if fs::write(&config_path, &config_content).is_err() {
        let _ = fs::remove_dir_all(&dir);
        return String::new();
    }

    let result = Command::new("curl")
        .args([
            "-sS",
            "--fail",
            "--max-time",
            "5",
            "-K",
            &config_path,
            "-L",
            url,
        ])
        .current_dir(repo_path)
        .output();

    let _ = fs::remove_dir_all(&dir);

    match result {
        Ok(o) if o.status.success() => String::from_utf8_lossy(&o.stdout).into_owned(),
        _ => String::new(),
    }
}

fn render_uncached(theme: Theme, theme_hex: &ThemeHex, repo_path: &str, provider: &str) -> String {
    let ctx = WidgetContext::from_theme_hex(theme, theme_hex);
    let theme = ctx.theme;
    let bg = theme_hex.color(theme.surface);

    let branch_raw = match run_git_command(
        &["git", "rev-parse", "--abbrev-ref", "HEAD"],
        Some(Path::new(repo_path)),
    ) {
        Ok(out) => out,
        Err(_) => return String::new(),
    };
    let branch_str = String::from_utf8_lossy(&branch_raw);
    let branch = branch_str.trim();
    if branch.is_empty() {
        return String::new();
    }

    let pr_count: usize;
    let review_count: usize;
    let issue_count: usize;
    let bug_count: usize;
    let provider_icon: &str;

    if provider == "github.com" {
        if !command_exists("gh") {
            return String::new();
        }
        provider_icon = "\u{F408} ";

        let pr_args = &[
            "gh", "pr", "list", "--json", "number", "--limit", "100", "--jq", "length",
        ][..];
        let review_args = &[
            "gh",
            "pr",
            "list",
            "--reviewer",
            "@me",
            "--json",
            "number",
            "--limit",
            "100",
            "--jq",
            "length",
        ][..];
        let issues_args = &[
            "gh",
            "issue",
            "list",
            "--json",
            "assignees,labels",
            "--assignee",
            "@me",
            "--limit",
            "100",
            "--jq",
            "length",
        ][..];
        let bugs_args = &[
            "gh",
            "issue",
            "list",
            "--json",
            "labels,assignees",
            "--assignee",
            "@me",
            "--limit",
            "100",
            "--jq",
            "[.[] | select(any(.labels[]?; .name == \"bug\"))] | length",
        ][..];

        let (pr_result, review_result, issues_result, bugs_result) = thread::scope(|s| {
            let pr_t = s.spawn(|| run_gh_command(pr_args, repo_path));
            let review_t = s.spawn(|| run_gh_command(review_args, repo_path));
            let issues_t = s.spawn(|| run_gh_command(issues_args, repo_path));
            let bugs_t = s.spawn(|| run_gh_command(bugs_args, repo_path));
            (
                pr_t.join().unwrap_or(Err(())),
                review_t.join().unwrap_or(Err(())),
                issues_t.join().unwrap_or(Err(())),
                bugs_t.join().unwrap_or(Err(())),
            )
        });

        pr_count = pr_result
            .ok()
            .and_then(|s| s.trim().parse::<usize>().ok())
            .unwrap_or(0);
        review_count = review_result
            .ok()
            .and_then(|s| s.trim().parse::<usize>().ok())
            .unwrap_or(0);
        let total_issues = issues_result
            .ok()
            .and_then(|s| s.trim().parse::<usize>().ok())
            .unwrap_or(0);
        bug_count = bugs_result
            .ok()
            .and_then(|s| s.trim().parse::<usize>().ok())
            .unwrap_or(0);
        issue_count = total_issues.saturating_sub(bug_count);
    } else if provider == "gitlab.com" {
        if !command_exists("glab") {
            return String::new();
        }
        provider_icon = "\u{E65C} ";
        bug_count = 0;

        let mr_args: &[&str] = &["glab", "mr", "list"];
        let review_args: &[&str] = &["glab", "mr", "list", "--reviewer=@me"];
        let issue_args: &[&str] = &["glab", "issue", "list"];

        let (mr_result, review_result, issue_result) = thread::scope(|s| {
            let mr_t = s.spawn(|| run_gh_command(mr_args, repo_path));
            let review_t = s.spawn(|| run_gh_command(review_args, repo_path));
            let issue_t = s.spawn(|| run_gh_command(issue_args, repo_path));
            (
                mr_t.join().unwrap_or(Err(())),
                review_t.join().unwrap_or(Err(())),
                issue_t.join().unwrap_or(Err(())),
            )
        });

        pr_count = mr_result
            .ok()
            .map(|s| count_lines_matching(&s, "!"))
            .unwrap_or(0);
        review_count = review_result
            .ok()
            .map(|s| count_lines_matching(&s, "!"))
            .unwrap_or(0);
        issue_count = issue_result
            .ok()
            .map(|s| count_lines_matching(&s, "#"))
            .unwrap_or(0);
    } else if provider == "codeberg.org" {
        if !command_exists("curl") {
            return String::new();
        }

        let token = match get_codeberg_token() {
            Some(t) if is_valid_token(&t) => t,
            _ => return String::new(),
        };

        provider_icon = "\u{F328} ";
        review_count = 0;
        bug_count = 0;

        let remote_url = match get_remote_url(repo_path) {
            Some(u) => u,
            None => return String::new(),
        };

        let owner_repo = match parse_codeberg_owner_repo(&remote_url) {
            Some(or) => or,
            None => return String::new(),
        };

        let api_base = "https://codeberg.org/api/v1";

        let pr_url = format!(
            "{}/repos/{}/pulls?state=open&limit=100",
            api_base, owner_repo
        );
        let issue_url = format!(
            "{}/repos/{}/issues?state=open&limit=100",
            api_base, owner_repo
        );

        let (pr_json, issue_json) = thread::scope(|s| {
            let pr_t = s.spawn(|| fetch_with_token(&pr_url, &token, repo_path));
            let issue_t = s.spawn(|| fetch_with_token(&issue_url, &token, repo_path));
            (pr_t.join().unwrap_or_default(), issue_t.join().unwrap_or_default())
        });
        pr_count = count_json_array_items(&pr_json);
        issue_count = count_json_array_items(&issue_json);
    } else {
        return String::new();
    }

    let mut result = String::with_capacity(512);

    // Forge header: muted  icon
    use std::fmt::Write;
    let _ = write!(
        result,
        "#[fg={},bg={},bold]\u{EB3A} {}",
        theme_hex.color(theme.muted),
        bg,
        ctx.reset,
    );

    // Provider icon with forge color
    let forge_color = if provider == "github.com" {
        theme.forge_github
    } else if provider == "codeberg.org" {
        theme.forge_codeberg
    } else {
        theme.forge_gitlab
    };
    let _ = write!(
        result,
        "#[fg={}]{} {}",
        theme_hex.color(forge_color),
        provider_icon,
        ctx.reset,
    );

    append_segment(
        &mut result,
        theme_hex,
        theme.success,
        &bg,
        "\u{F407}",
        pr_count,
        &ctx.reset,
    );
    append_segment(
        &mut result,
        theme_hex,
        theme.warning,
        &bg,
        "\u{F4AF}",
        review_count,
        &ctx.reset,
    );
    append_segment(
        &mut result,
        theme_hex,
        theme.success,
        &bg,
        "\u{F41B}",
        issue_count,
        &ctx.reset,
    );
    append_segment(
        &mut result,
        theme_hex,
        theme.danger,
        &bg,
        "\u{F46F}",
        bug_count,
        &ctx.reset,
    );

    result
}

/// Render the forge (GitHub/GitLab/Codeberg) widget with caching.
pub fn run(theme: Theme, repo_path: &str, cache_ttl: u64) -> String {
    let theme_hex = ThemeHex::from_theme(theme);
    run_with_theme_hex(theme, &theme_hex, repo_path, cache_ttl)
}

pub(crate) fn run_with_theme_hex(
    theme: Theme,
    theme_hex: &ThemeHex,
    repo_path: &str,
    cache_ttl: u64,
) -> String {
    let remote_url = match get_remote_url(repo_path) {
        Some(u) => u,
        None => return String::new(),
    };

    let provider = match provider_from_url(&remote_url) {
        Some(p) => p,
        None => return String::new(),
    };

    let head_hash = get_head_hash(repo_path);

    let path = cache_path(repo_path, &remote_url, head_hash.as_deref());

    if let Some(cached) = read_fresh_cache(&path, cache_ttl) {
        return cached;
    }

    let output = render_uncached(theme, theme_hex, repo_path, &provider);

    if !output.is_empty() {
        write_cache(&path, &output);
    }

    output
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn provider_from_url_extracts_host_from_ssh_and_https_urls() {
        assert_eq!(
            Some("github.com".to_owned()),
            provider_from_url("git@github.com:user/repo.git")
        );
        assert_eq!(
            Some("gitlab.com".to_owned()),
            provider_from_url("https://gitlab.com/user/repo")
        );
        assert_eq!(None, provider_from_url("ftp://example.com/repo"));
    }

    #[test]
    fn parse_codeberg_owner_repo_extracts_owner_repo_from_codeberg_urls() {
        assert_eq!(
            Some("owner/repo".to_owned()),
            parse_codeberg_owner_repo("git@codeberg.org:owner/repo.git")
        );
        assert_eq!(
            Some("owner/repo".to_owned()),
            parse_codeberg_owner_repo("https://codeberg.org/owner/repo")
        );
        assert_eq!(
            None,
            parse_codeberg_owner_repo("https://github.com/owner/repo")
        );
    }

    #[test]
    fn count_lines_matching_counts_lines_with_prefix() {
        let text = "!123\n#456\n!789\n\nabc\n";
        assert_eq!(2, count_lines_matching(text, "!"));
        assert_eq!(1, count_lines_matching(text, "#"));
        assert_eq!(0, count_lines_matching(text, "x"));
    }

    #[test]
    fn is_valid_token_rejects_control_characters() {
        assert!(is_valid_token("abc123"));
        assert!(is_valid_token("token_with-special.chars"));
        assert!(!is_valid_token("bad\ntoken"));
        assert!(!is_valid_token("bad\rtoken"));
        assert!(!is_valid_token("\x00null"));
        assert!(!is_valid_token("del\x7F"));
    }
}
