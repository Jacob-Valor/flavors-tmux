use std::collections::hash_map::DefaultHasher;
use std::fs;
use std::hash::Hasher;
use std::path::{Path, PathBuf};
use std::process::Command;

use crate::core::cache::{cache_base, read_fresh_cache, write_cache};
use crate::core::widget::WidgetContext;
use crate::core::Theme;
use crate::tmux_renderer::ThemeHex;

const CACHE_TTL_SECONDS: u64 = 2;

fn absolute_path(path: &Path) -> PathBuf {
    if let Ok(canonical) = fs::canonicalize(path) {
        return canonical;
    }
    if path.is_absolute() {
        return path.to_path_buf();
    }
    match std::env::current_dir() {
        Ok(current) => current.join(path),
        Err(_) => path.to_path_buf(),
    }
}

fn cache_path(absolute_cwd: &Path) -> String {
    let mut hasher = DefaultHasher::new();
    hasher.write(absolute_cwd.to_string_lossy().as_bytes());
    let key = hasher.finish();

    format!("{}/flavors-tmux-cwd-{:x}.cache", cache_base(), key)
}

fn git_repo_root(cwd: &Path) -> String {
    match Command::new("git")
        .args(["rev-parse", "--show-toplevel"])
        .current_dir(cwd)
        .output()
    {
        Ok(output) if output.status.success() => {
            String::from_utf8(output.stdout).unwrap_or_default().trim().to_owned()
        }
        _ => String::new(),
    }
}

fn cached_git_repo_root(absolute_cwd: &Path) -> String {
    let path = cache_path(absolute_cwd);
    if let Some(cached) = read_fresh_cache(&path, CACHE_TTL_SECONDS) {
        return cached;
    }

    let repo_root = git_repo_root(absolute_cwd);
    write_cache(&path, &repo_root);
    repo_root
}

fn display_path(basename: String, repo_root: &str) -> String {
    if repo_root.is_empty() {
        return basename;
    }

    let repo_name = Path::new(repo_root)
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();
    if repo_name.is_empty() || repo_name == basename {
        basename
    } else {
        format!("{}/{}", repo_name, basename)
    }
}

/// Render the current working directory widget.
/// Shows `󰉋 basename` outside a git repo, or `󰉋 repo-name/basename` inside one.
pub fn run(theme: Theme, cwd: &str) -> String {
    let theme_hex = ThemeHex::from_theme(theme);
    run_with_theme_hex(theme, &theme_hex, cwd)
}

pub(crate) fn run_with_theme_hex(theme: Theme, theme_hex: &ThemeHex, cwd: &str) -> String {
    let ctx = WidgetContext::from_theme_hex(theme, theme_hex);
    let theme = ctx.theme;

    if cwd.is_empty() {
        return String::new();
    }

    let path = Path::new(cwd);
    let basename = match path.file_name() {
        Some(name) => name.to_string_lossy().into_owned(),
        None => return String::new(),
    };

    let absolute_cwd = absolute_path(path);
    let repo_root = cached_git_repo_root(&absolute_cwd);
    let display_path = display_path(basename, &repo_root);

    format!(
        "{}#[fg={},bg={},bold]󰉋 {}",
        ctx.reset,
        theme_hex.color(theme.emphasis),
        theme_hex.color(theme.surface),
        display_path,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::themes;

    #[test]
    fn cwd_produces_output_for_tmp_dir() {
        let output = run(themes::hard::THEME, "/tmp");
        assert!(output.contains("#[fg="));
        assert!(output.contains("󰉋"));
    }

    #[test]
    fn display_path_uses_basename_when_repo_root_is_empty() {
        let output = display_path(String::from("project"), "");

        assert_eq!(output, "project");
    }

    #[test]
    fn display_path_prefixes_repo_name_when_inside_repo_subdir() {
        let output = display_path(String::from("src"), "/work/project");

        assert_eq!(output, "project/src");
    }

    #[test]
    fn run_uses_fresh_cached_repo_root_when_present() {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let cwd = std::env::temp_dir().join(format!("flavors-tmux-cwd-test-{unique}"));
        std::fs::create_dir_all(&cwd).unwrap();
        let absolute_cwd = absolute_path(&cwd);
        let cache = cache_path(&absolute_cwd);
        write_cache(&cache, "/work/fake-repo");

        let output = run(themes::hard::THEME, &cwd.to_string_lossy());

        assert!(output.contains("fake-repo/"));
        std::fs::remove_file(cache).unwrap();
        std::fs::remove_dir_all(cwd).unwrap();
    }
}
