use std::process::Command;

use crate::core::widget::WidgetContext;
use crate::core::{Color, Theme};
use crate::tmux_renderer;

fn get_kubectl_output(argv: &[&str]) -> Option<String> {
    let output = Command::new("kubectl").args(argv).output().ok()?;
    if !output.status.success() {
        return None;
    }
    let trimmed = String::from_utf8_lossy(&output.stdout).trim().to_owned();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed)
    }
}

fn context_contains(context: &str, needle: &str) -> bool {
    context.to_lowercase().contains(&needle.to_lowercase())
}

fn context_matches_any(context: &str, needles: &[&str]) -> bool {
    needles
        .iter()
        .any(|needle| context_contains(context, needle))
}

fn context_color(theme: Theme, context: &str) -> Color {
    if context_matches_any(context, &["prod", "production"]) {
        theme.danger
    } else if context_matches_any(context, &["stage", "staging", "dev", "development"]) {
        theme.warning
    } else {
        theme.info
    }
}

/// Render the Kubernetes context widget.
/// Shows `󱃾 context/namespace` colored by environment (danger=prod, warning=stage/dev, info=other).
pub fn run(theme_name: &str, transparent: bool) -> String {
    let ctx = WidgetContext::new(theme_name, transparent);
    let theme = ctx.theme;

    let context = match get_kubectl_output(&["config", "current-context"]) {
        Some(c) => c,
        None => return String::new(),
    };

    let namespace = get_kubectl_output(&[
        "config",
        "view",
        "--minify",
        "--output",
        "jsonpath={..namespace}",
    ])
    .unwrap_or_else(|| String::from("default"));

    let color = context_color(theme, &context);

    format!(
        "{}#[fg={},bg={},bold]󱃾 {}/{}",
        ctx.reset,
        tmux_renderer::color_hex_string(color),
        tmux_renderer::color_hex_string(theme.background),
        context,
        namespace,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::themes;

    #[test]
    fn context_color_maps_environment_names_semantically() {
        let theme = themes::hard::THEME;
        assert_eq!(theme.danger, context_color(theme, "prod-cluster"));
        assert_eq!(theme.warning, context_color(theme, "staging-cluster"));
        assert_eq!(theme.warning, context_color(theme, "dev-cluster"));
        assert_eq!(theme.info, context_color(theme, "sandbox"));
    }
}
