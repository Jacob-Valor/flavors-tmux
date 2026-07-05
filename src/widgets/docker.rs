use std::process::Command;

use crate::core::widget::WidgetContext;
use crate::tmux_renderer;

/// Render the Docker context widget.
/// Shows ` <context>` — muted for `default`, info for all others.
pub fn run(theme_name: &str, transparent: bool) -> String {
    let ctx = WidgetContext::new(theme_name, transparent);
    let theme = ctx.theme;

    let context = match Command::new("docker").args(["context", "show"]).output() {
        Ok(output) if output.status.success() => {
            String::from_utf8_lossy(&output.stdout).trim().to_owned()
        }
        _ => return String::new(),
    };

    if context.is_empty() {
        return String::new();
    }

    let color = if context == "default" {
        theme.muted
    } else {
        theme.info
    };

    format!(
        "{}#[fg={},bg={},bold] {}",
        ctx.reset,
        tmux_renderer::color_hex_string(color),
        tmux_renderer::color_hex_string(theme.background),
        context,
    )
}
