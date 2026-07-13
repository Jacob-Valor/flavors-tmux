use std::process::Command;

use crate::core::widget::WidgetContext;
use crate::core::Theme;
use crate::tmux_renderer::ThemeHex;

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

    let workspace = match Command::new("terraform")
        .args(["workspace", "show"])
        .current_dir(cwd)
        .output()
    {
        Ok(output) if output.status.success() => {
            String::from_utf8_lossy(&output.stdout).trim().to_owned()
        }
        _ => return String::new(),
    };

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
