use std::process::Command;

use crate::core::util::{parse_porcelain, PorcelainStatus};
use crate::core::widget::WidgetContext;
use crate::tmux_renderer;

fn get_yadm_status() -> Option<PorcelainStatus> {
    let output = Command::new("yadm")
        .args(["status", "--porcelain"])
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    Some(parse_porcelain(&stdout))
}

/// Render the YADM dotfiles status widget.
/// Clean repo shows just `󰃣`; dirty shows `󰃣` + changed `` + untracked ``.
pub fn run(theme_name: &str, transparent: bool) -> String {
    let ctx = WidgetContext::new(theme_name, transparent);
    let theme = ctx.theme;

    let status = match get_yadm_status() {
        Some(s) => s,
        None => return String::new(),
    };

    let bg = tmux_renderer::color_hex_string(theme.background);

    if status.changed == 0 && status.untracked == 0 {
        return format!(
            "{}#[fg={},bg={},bold]󰃣",
            ctx.reset,
            tmux_renderer::color_hex_string(theme.muted),
            bg,
        );
    }

    let mut result = format!(
        "{}#[fg={},bg={},bold]󰃣",
        ctx.reset,
        tmux_renderer::color_hex_string(theme.muted),
        bg,
    );

    if status.changed > 0 {
        result.push_str(&format!(
            " #[fg={},bg={},bold] {}",
            tmux_renderer::color_hex_string(theme.warning),
            bg,
            status.changed,
        ));
    }

    if status.untracked > 0 {
        result.push_str(&format!(
            " #[fg={},bg={},bold] {}",
            tmux_renderer::color_hex_string(theme.muted),
            bg,
            status.untracked,
        ));
    }

    result
}
