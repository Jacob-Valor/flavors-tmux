use std::process::Command;

use crate::core::cache::{cached_or_compute, scoped_cache_path};
use crate::core::widget::WidgetContext;
use crate::core::Theme;
use crate::tmux_renderer::ThemeHex;

// The active context rarely changes and `docker context show` has real CLI
// startup cost (daemon/socket handshake), so a short cache turns a ~18ms
// subprocess spawn into a near-free file read on most renders. Tradeoff: a
// `docker context use` switch can take up to this long to show up.
const DOCKER_CONTEXT_CACHE_TTL_SECS: u64 = 5;

fn docker_context() -> String {
    match Command::new("docker").args(["context", "show"]).output() {
        Ok(output) if output.status.success() => {
            String::from_utf8(output.stdout).unwrap_or_default().trim().to_owned()
        }
        _ => String::new(),
    }
}

/// Render the Docker context widget.
/// Shows ` <context>` — muted for `default`, info for all others.
pub fn run(theme: Theme) -> String {
    let theme_hex = ThemeHex::from_theme(theme);
    run_with_theme_hex(theme, &theme_hex)
}

pub(crate) fn run_with_theme_hex(theme: Theme, theme_hex: &ThemeHex) -> String {
    let ctx = WidgetContext::from_theme_hex(theme, theme_hex);
    let theme = ctx.theme;

    let cache_path = scoped_cache_path("docker-context", None);
    let context = cached_or_compute(&cache_path, DOCKER_CONTEXT_CACHE_TTL_SECS, docker_context);

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
