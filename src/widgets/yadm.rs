use std::process::Command;

use crate::core::util::{parse_porcelain, PorcelainStatus};
use crate::core::widget::WidgetContext;
use crate::core::Theme;
use crate::tmux_renderer::ThemeHex;

fn get_yadm_status() -> Option<PorcelainStatus> {
    let output = Command::new("yadm")
        .args(["status", "--porcelain"])
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let stdout = String::from_utf8(output.stdout).unwrap_or_default();
    Some(parse_porcelain(&stdout))
}

/// Render the YADM dotfiles status widget.
/// Clean repo shows just `󰃣`; dirty shows `󰃣` + changed `` + untracked ``.
pub fn run(theme: Theme) -> String {
    let theme_hex = ThemeHex::from_theme(theme);
    run_with_theme_hex(theme, &theme_hex)
}

pub(crate) fn run_with_theme_hex(theme: Theme, theme_hex: &ThemeHex) -> String {
    let ctx = WidgetContext::from_theme_hex(theme, theme_hex);
    let theme = ctx.theme;

    let status = match get_yadm_status() {
        Some(s) => s,
        None => return String::new(),
    };

    let bg = theme_hex.color(theme.surface);

    if status.changed == 0 && status.untracked == 0 {
        return format!(
            "{}#[fg={},bg={},bold]󰃣",
            ctx.reset,
            theme_hex.color(theme.muted),
            bg,
        );
    }

    let mut result = format!(
        "{}#[fg={},bg={},bold]󰃣",
        ctx.reset,
        theme_hex.color(theme.muted),
        bg,
    );

    if status.changed > 0 {
        result.push_str(&format!(
            " #[fg={},bg={},bold] {}",
            theme_hex.color(theme.warning),
            bg,
            status.changed,
        ));
    }

    if status.untracked > 0 {
        result.push_str(&format!(
            " #[fg={},bg={},bold] {}",
            theme_hex.color(theme.muted),
            bg,
            status.untracked,
        ));
    }

    result
}
