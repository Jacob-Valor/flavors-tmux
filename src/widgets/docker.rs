use std::process::Command;

use crate::core::widget::WidgetContext;
use crate::core::Theme;
use crate::tmux_renderer::ThemeHex;

/// Render the Docker context widget.
/// Shows ` <context>` — muted for `default`, info for all others.
pub fn run(theme: Theme) -> String {
    let theme_hex = ThemeHex::from_theme(theme);
    run_with_theme_hex(theme, &theme_hex)
}

pub(crate) fn run_with_theme_hex(theme: Theme, theme_hex: &ThemeHex) -> String {
    let ctx = WidgetContext::from_theme_hex(theme, theme_hex);
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
        "{}#[fg={},bg={},bold] {}",
        ctx.reset,
        theme_hex.color(color),
        theme_hex.color(theme.surface),
        context,
    )
}
