use std::collections::hash_map::DefaultHasher;
use std::env;
use std::fs;
use std::hash::Hasher;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use std::process::Command;
use std::sync::atomic::{AtomicU64, Ordering};
use std::thread;

use crate::core::cache::{cache_base, read_cache_any_age, read_fresh_cache, write_cache};
use crate::core::util::run_git_command;
use crate::core::widget::WidgetContext;
use crate::core::{Color, Theme};
use crate::tmux_renderer::ThemeHex;

/// Raw forge data — theme-independent, so the background refresh subcommand
/// can recompute it without knowing the theme, and any theme can render it.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct ForgeData {
    pub provider: ForgeProvider,
    pub pr_count: usize,
    pub review_count: usize,
    pub issue_count: usize,
    pub bug_count: usize,
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum ForgeProvider {
    #[default]
    None,
    Github,
    Gitlab,
    Codeberg,
}

impl ForgeProvider {
    fn icon(self) -> &'static str {
        match self {
            Self::Github => "\u{F408} ",
            Self::Gitlab => "\u{E65C} ",
            Self::Codeberg => "\u{F328} ",
            Self::None => "",
        }
    }
}

/// Serialize raw forge data to the cache file. Line format:
/// `provider pr review issue bug` — no theme dependency.
fn serialize(data: &ForgeData) -> String {
    let provider = match data.provider {
        ForgeProvider::Github => "github",
        ForgeProvider::Gitlab => "gitlab",
        ForgeProvider::Codeberg => "codeberg",
        ForgeProvider::None => "none",
    };
    format!(
        "{provider} {} {} {} {}",
        data.pr_count, data.review_count, data.issue_count, data.bug_count
    )
}

fn deserialize(content: &str) -> Option<ForgeData> {
    let mut parts = content.split_whitespace();
    let provider = match parts.next()? {
        "github" => ForgeProvider::Github,
        "gitlab" => ForgeProvider::Gitlab,
        "codeberg" => ForgeProvider::Codeberg,
        _ => return None,
    };
    Some(ForgeData {
        provider,
        pr_count: parts.next()?.parse().ok()?,
        review_count: parts.next()?.parse().ok()?,
        issue_count: parts.next()?.parse().ok()?,
        bug_count: parts.next()?.parse().ok()?,
    })
}

/// Cache key derived from the repo path only — the cached payload is raw
/// (theme-independent) forge data, so no theme hash is needed in the key.
/// A fresh cache hit is a single file read with zero subprocess spawns.
fn cache_path(repo_path: &str) -> String {
    let mut hasher = DefaultHasher::new();
    hasher.write(repo_path.as_bytes());
    let key = hasher.finish();

    format!("{}/flavors-tmux-wb-{:x}.cache", cache_base(), key)
}

/// Spawn a fully-detached background process (new session, no stdio) that
/// recomputes the forge cache for `repo_path` and writes it. The statusline
/// returns immediately; the refresh finishes whenever the network round-trips
/// finish. If the child fails to spawn (rare), the next render retries.
fn spawn_background_refresh(repo_path: &str) {
    use std::os::unix::process::CommandExt;
    let exe = match env::current_exe() {
        Ok(e) => e,
        Err(_) => return,
    };
    let mut cmd = Command::new(exe);
    cmd.arg("wb-git-refresh")
        .arg(repo_path)
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null());
    // New process group so the child isn't killed when tmux reaps the status
    // process, and isn't tied to our stdout pipe. Combined with null stdio,
    // this fully detaches the refresh from the statusline lifecycle.
    cmd.process_group(0);
    let _ = cmd.spawn();
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

/// Get the first remote's URL with a single subprocess spawn.
fn get_remote_url(repo_path: &str) -> Option<String> {
    let stdout = run_git_command(
        &["git", "remote", "get-url", "origin"],
        Some(Path::new(repo_path)),
    )
    .ok()?;
    let remote_url = String::from_utf8(stdout)
        .unwrap_or_default()
        .trim()
        .to_owned();
    if remote_url.is_empty() {
        None
    } else {
        Some(remote_url)
    }
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
    // from_utf8 moves the Vec into the String without re-allocating when valid.
    Ok(String::from_utf8(output.stdout).unwrap_or_default())
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
        // from_utf8 moves the Vec into the String without re-allocating when valid.
        Ok(o) if o.status.success() => String::from_utf8(o.stdout).unwrap_or_default(),
        _ => String::new(),
    }
}

/// Fetch raw forge data (PR/review/issue/bug counts + provider) for `repo_path`.
/// Theme-independent — used both by the render path and the background
/// `wb-git-refresh` subcommand.
fn compute_data(repo_path: &str) -> ForgeData {
    let remote_url = match get_remote_url(repo_path) {
        Some(u) => u,
        None => return ForgeData::default(),
    };
    let provider = match provider_from_url(&remote_url) {
        Some(p) => p,
        None => return ForgeData::default(),
    };

    let branch_raw = match run_git_command(
        &["git", "rev-parse", "--abbrev-ref", "HEAD"],
        Some(Path::new(repo_path)),
    ) {
        Ok(out) => out,
        Err(_) => return ForgeData::default(),
    };
    let branch = String::from_utf8(branch_raw).unwrap_or_default();
    let branch = branch.trim();
    if branch.is_empty() {
        return ForgeData::default();
    }

    let mut data = ForgeData {
        provider: match provider.as_str() {
            "github.com" => ForgeProvider::Github,
            "gitlab.com" => ForgeProvider::Gitlab,
            "codeberg.org" => ForgeProvider::Codeberg,
            _ => return ForgeData::default(),
        },
        ..ForgeData::default()
    };

    if data.provider == ForgeProvider::Github {
        if !command_exists("gh") {
            return ForgeData::default();
        }

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

        data.pr_count = pr_result
            .ok()
            .and_then(|s| s.trim().parse::<usize>().ok())
            .unwrap_or(0);
        data.review_count = review_result
            .ok()
            .and_then(|s| s.trim().parse::<usize>().ok())
            .unwrap_or(0);
        let total_issues = issues_result
            .ok()
            .and_then(|s| s.trim().parse::<usize>().ok())
            .unwrap_or(0);
        data.bug_count = bugs_result
            .ok()
            .and_then(|s| s.trim().parse::<usize>().ok())
            .unwrap_or(0);
        data.issue_count = total_issues.saturating_sub(data.bug_count);
    } else if data.provider == ForgeProvider::Gitlab {
        if !command_exists("glab") {
            return ForgeData::default();
        }

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

        data.pr_count = mr_result
            .ok()
            .map(|s| count_lines_matching(&s, "!"))
            .unwrap_or(0);
        data.review_count = review_result
            .ok()
            .map(|s| count_lines_matching(&s, "!"))
            .unwrap_or(0);
        data.issue_count = issue_result
            .ok()
            .map(|s| count_lines_matching(&s, "#"))
            .unwrap_or(0);
    } else if data.provider == ForgeProvider::Codeberg {
        if !command_exists("curl") {
            return ForgeData::default();
        }

        let token = match get_codeberg_token() {
            Some(t) if is_valid_token(&t) => t,
            _ => return ForgeData::default(),
        };

        let owner_repo = match parse_codeberg_owner_repo(&remote_url) {
            Some(or) => or,
            None => return ForgeData::default(),
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
            (
                pr_t.join().unwrap_or_default(),
                issue_t.join().unwrap_or_default(),
            )
        });
        data.pr_count = count_json_array_items(&pr_json);
        data.issue_count = count_json_array_items(&issue_json);
    }

    data
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
    // Hot path first: a fresh cache hit costs a single file read and zero
    // subprocess spawns (no `git remote` query needed for the key).
    let path = cache_path(repo_path);

    // Stale-while-revalidate: if a cache exists but is older than the TTL,
    // render the stale content immediately and kick off a detached background
    // refresh. The statusline never blocks on gh/glab/curl.
    if let Some((content, _age)) = read_cache_any_age(&path) {
        if let Some(data) = deserialize(&content) {
            // Only revalidate if the entry is actually stale — `read_fresh_cache`
            // returning None could also mean the file is missing.
            if read_fresh_cache(&path, cache_ttl).is_none() {
                spawn_background_refresh(repo_path);
            }
            return render_data(theme, theme_hex, &data);
        }
    }

    let data = compute_data(repo_path);
    if data.provider != ForgeProvider::None {
        write_cache(&path, &serialize(&data));
        return render_data(theme, theme_hex, &data);
    }

    String::new()
}

/// Recompute the forge cache for `repo_path` in the background and write it.
/// Called by the detached `wb-git-refresh` subcommand — no rendering, no
/// stdout. Returns true when a cache entry was written (or refreshed).
pub fn refresh_cache(repo_path: &str) -> bool {
    let data = compute_data(repo_path);
    if data.provider == ForgeProvider::None {
        return false;
    }
    write_cache(&cache_path(repo_path), &serialize(&data));
    true
}

/// Render raw forge data with theme colors.
fn render_data(theme: Theme, theme_hex: &ThemeHex, data: &ForgeData) -> String {
    let ctx = WidgetContext::from_theme_hex(theme, theme_hex);
    let theme = ctx.theme;
    let bg = theme_hex.color(theme.surface);

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
    let forge_color = match data.provider {
        ForgeProvider::Github => theme.forge_github,
        ForgeProvider::Codeberg => theme.forge_codeberg,
        _ => theme.forge_gitlab,
    };
    let _ = write!(
        result,
        "#[fg={}]{} {}",
        theme_hex.color(forge_color),
        data.provider.icon(),
        ctx.reset,
    );

    append_segment(
        &mut result,
        theme_hex,
        theme.success,
        &bg,
        "\u{F407}",
        data.pr_count,
        &ctx.reset,
    );
    append_segment(
        &mut result,
        theme_hex,
        theme.warning,
        &bg,
        "\u{F4AF}",
        data.review_count,
        &ctx.reset,
    );
    append_segment(
        &mut result,
        theme_hex,
        theme.success,
        &bg,
        "\u{F41B}",
        data.issue_count,
        &ctx.reset,
    );
    append_segment(
        &mut result,
        theme_hex,
        theme.danger,
        &bg,
        "\u{F46F}",
        data.bug_count,
        &ctx.reset,
    );

    result
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
