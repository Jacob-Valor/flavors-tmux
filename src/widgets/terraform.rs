use std::process::Command;

use crate::core::cache::{cached_or_compute, scoped_cache_path};
use crate::core::widget::WidgetContext;
use crate::core::Theme;
use crate::tmux_renderer::ThemeHex;

// `terraform workspace show` has to load the working directory's state/lock
// files on every call, which is slow relative to most CLI invocations.
// Tradeoff: `terraform workspace select` can take up to this long to show
// up in the statusline.
const TERRAFORM_CACHE_TTL_SECS: u64 = 5;

fn terraform_workspace(cwd: &str) -> String {
    match Command::new("terraform")
        .args(["workspace", "show"])
        .current_dir(cwd)
        .output()
    {
        Ok(output) if output.status.success() => {
            String::from_utf8_lossy(&output.stdout).trim().to_owned()
        }
        _ => String::new(),
    }
}

/// Render the Terraform workspace widget.
/// Shows `󱁢 workspace` — muted for `default`, primary for all others.
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

    let cache_path = scoped_cache_path("terraform-workspace", Some(cwd));
    let workspace = cached_or_compute(&cache_path, TERRAFORM_CACHE_TTL_SECS, || {
        terraform_workspace(cwd)
    });

    if workspace.is_empty() {
        return String::new();
    }

    let color = if workspace == "default" {
        theme.muted
    } else {
        theme.primary
    };

    format!(
        "{}#[fg={},bg={},bold]󱁢 {}",
        ctx.reset,
        theme_hex.color(color),
        theme_hex.color(theme.surface),
        workspace,
    )
}
