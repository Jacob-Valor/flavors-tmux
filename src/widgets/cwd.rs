use std::path::Path;
use std::process::Command;

use crate::core::widget::WidgetContext;
use crate::core::Theme;
use crate::tmux_renderer;

/// Render the current working directory widget.
/// Shows `󰉋 basename` outside a git repo, or `󰉋 repo-name/basename` inside one.
pub fn run(theme: Theme, cwd: &str) -> String {
    let ctx = WidgetContext::from_theme(theme);
    let theme = ctx.theme;

    if cwd.is_empty() {
        return String::new();
    }

    let path = Path::new(cwd);
    let basename = match path.file_name() {
        Some(name) => name.to_string_lossy().into_owned(),
        None => return String::new(),
    };

    // Try to get git repo root for relative display
    let display_path = match Command::new("git")
        .args(["rev-parse", "--show-toplevel"])
        .current_dir(path)
        .output()
    {
        Ok(output) if output.status.success() => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let repo_root = stdout.trim();
            if repo_root.is_empty() {
                basename
            } else {
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
        }
        _ => basename,
    };

    format!(
        "{}#[fg={},bg={},bold]󰉋 {}",
        ctx.reset,
        tmux_renderer::color_hex_string(theme.emphasis),
        tmux_renderer::color_hex_string(theme.background),
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
}
