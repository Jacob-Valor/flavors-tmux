use std::env;

use crate::core::widget::WidgetContext;
use crate::core::Theme;
use crate::tmux_renderer;

/// Render the hostname/SSH indicator widget.
/// Shows `▒ 󰌽 hostname` (muted) locally or `▒ 󰣀 hostname` (warning) over SSH.
pub fn run(theme: Theme) -> String {
    let ctx = WidgetContext::from_theme(theme);
    let theme = ctx.theme;

    let is_ssh = env::var_os("SSH_CONNECTION").is_some() || env::var_os("SSH_CLIENT").is_some();

    let hostname = match env::var("HOSTNAME") {
        Ok(h) if !h.is_empty() => h,
        _ => {
            // Fall back to `hostname` command, then "unknown"
            std::process::Command::new("hostname")
                .output()
                .ok()
                .and_then(|o| {
                    if o.status.success() {
                        Some(String::from_utf8_lossy(&o.stdout).trim().to_owned())
                    } else {
                        None
                    }
                })
                .unwrap_or_else(|| String::from("unknown"))
        }
    };

    let (icon, color) = if is_ssh {
        ("󰣀", theme.warning)
    } else {
        ("󰌽", theme.muted)
    };

    format!(
        "{}#[fg={},bg={},bold]▒ {} {}",
        ctx.reset,
        tmux_renderer::color_hex_string(color),
        tmux_renderer::color_hex_string(theme.background),
        icon,
        hostname,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::themes;

    #[test]
    fn hostname_produces_output_with_expected_format() {
        let output = run(themes::hard::THEME);
        assert!(output.contains("#[fg="));
        assert!(output.contains("󰌽") || output.contains("󰣀"));
    }
}
