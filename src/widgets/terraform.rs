use std::process::Command;

use crate::core::widget::WidgetContext;
use crate::core::Theme;
use crate::tmux_renderer;

/// Render the Terraform workspace widget.
/// Shows `󱁢 workspace` — muted for `default`, primary for all others.
pub fn run(theme: Theme, cwd: &str) -> String {
    let ctx = WidgetContext::from_theme(theme);
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
        tmux_renderer::color_hex_string(color),
        tmux_renderer::color_hex_string(theme.background),
        workspace,
    )
}
