use std::process::Command;

use crate::core::cache::{cached_or_compute, scoped_cache_path};
use crate::core::widget::WidgetContext;
use crate::core::{Color, Theme};
use crate::tmux_renderer::ThemeHex;

// kubectl reads/validates the full kubeconfig on every invocation (and can
// hit the cluster API for some subcommands), so it is consistently the
// slowest of the subprocess-backed widgets. Two kubectl calls are needed per
// render (context, then namespace) — caching both together turns that into
// one cheap file read on most renders. Tradeoff: a `kubectl config
// use-context` / namespace switch can take up to this long to show up.
const KUBERNETES_CACHE_TTL_SECS: u64 = 5;

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
pub fn run(theme: Theme) -> String {
    let theme_hex = ThemeHex::from_theme(theme);
    run_with_theme_hex(theme, &theme_hex)
}

fn context_and_namespace() -> String {
    let context = get_kubectl_output(&["config", "current-context"]).unwrap_or_default();
    if context.is_empty() {
        // Cache the miss too, so a machine with no kubeconfig doesn't retry
        // kubectl on every render.
        return String::new();
    }

    let namespace = get_kubectl_output(&[
        "config",
        "view",
        "--minify",
        "--output",
        "jsonpath={..namespace}",
    ])
    .unwrap_or_else(|| String::from("default"));

    format!("{context}\n{namespace}")
}

pub(crate) fn run_with_theme_hex(theme: Theme, theme_hex: &ThemeHex) -> String {
    let ctx = WidgetContext::from_theme_hex(theme, theme_hex);
    let theme = ctx.theme;

    let cache_path = scoped_cache_path("kubernetes-context", None);
    let cached = cached_or_compute(&cache_path, KUBERNETES_CACHE_TTL_SECS, context_and_namespace);

    let mut parts = cached.splitn(2, '\n');
    let context = match parts.next() {
        Some(c) if !c.is_empty() => c,
        _ => return String::new(),
    };
    let namespace = parts.next().unwrap_or("default");

    let color = context_color(theme, context);

    format!(
        "{}#[fg={},bg={},bold]󱃾 {}/{}",
        ctx.reset,
        theme_hex.color(color),
        theme_hex.color(theme.surface),
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
