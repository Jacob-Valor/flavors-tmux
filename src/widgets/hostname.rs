use std::env;

use crate::core::widget::WidgetContext;
use crate::core::Theme;
use crate::tmux_renderer::ThemeHex;

/// Render the hostname/SSH indicator widget.
/// Shows `▒ 󰌽 hostname` (muted) locally or `▒ 󰣀 hostname` (warning) over SSH.
pub fn run(theme: Theme) -> String {
    let theme_hex = ThemeHex::from_theme(theme);
    run_with_theme_hex(theme, &theme_hex)
}

pub(crate) fn run_with_theme_hex(theme: Theme, theme_hex: &ThemeHex) -> String {
    let ctx = WidgetContext::from_theme_hex(theme, theme_hex);
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
        theme_hex.color(color),
        theme_hex.color(theme.surface),
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
