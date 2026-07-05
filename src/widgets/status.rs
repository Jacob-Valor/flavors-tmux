use crate::cli::args::TimeFormat;
use crate::themes;
use crate::tmux_renderer;
use crate::widgets;
use crate::widgets::status_entries::{color_from_theme, lookup_entry, WidgetColor, WidgetEntry};
use std::thread;

/// Shared config passed to widget rendering functions.
#[derive(Clone, Copy)]
pub struct WidgetConfig<'a> {
    pub theme_name: &'a str,
    pub transparent: bool,
    pub pane_path: &'a str,
    pub battery_name: Option<&'a str>,
    pub low_threshold: u8,
    pub time_format: TimeFormat,
    pub cache_ttl: u64,
}

fn render_widget(cfg: WidgetConfig<'_>, widget_name: &str) -> Option<String> {
    let output = match widget_name {
        "cwd" => widgets::cwd::run(cfg.theme_name, cfg.transparent, cfg.pane_path),
        "git" => widgets::git_status::run(cfg.theme_name, cfg.transparent, cfg.pane_path),
        "wb-git" => widgets::wb_git_status::run(cfg.theme_name, cfg.transparent, cfg.pane_path, cfg.cache_ttl),
        "cpu" => widgets::cpu_memory::run(cfg.theme_name, cfg.transparent),
        "hostname" => widgets::hostname::run(cfg.theme_name, cfg.transparent),
        "datetime" => widgets::datetime::run(cfg.theme_name, cfg.time_format, cfg.transparent),
        "battery" => widgets::battery::run(cfg.theme_name, cfg.transparent, cfg.battery_name, cfg.low_threshold),
        "kubernetes" => widgets::kubernetes::run(cfg.theme_name, cfg.transparent),
        "terraform" => widgets::terraform::run(cfg.theme_name, cfg.transparent, cfg.pane_path),
        "docker" => widgets::docker::run(cfg.theme_name, cfg.transparent),
        "yadm" => widgets::yadm::run(cfg.theme_name, cfg.transparent),
        "gpg-ssh" => widgets::gpg_ssh_agent::run(cfg.theme_name, cfg.transparent),
        _ => return None,
    };

    if output.is_empty() {
        None
    } else {
        Some(output)
    }
}

/// Assemble the full tmux status-right string from multiple widgets.
/// Each widget output is wrapped with its assigned color on the surface_alt background.
pub fn run(
    cfg: WidgetConfig<'_>,
    show_names: &[&str],
) -> String {
    let theme = themes::by_name(cfg.theme_name).with_transparent_background(cfg.transparent);

    struct WidgetOutput {
        text: String,
        color: WidgetColor,
        no_sep: bool,
    }

    let jobs: Vec<(&str, WidgetEntry)> = show_names
        .iter()
        .filter_map(|&name| lookup_entry(name).map(|entry| (name, entry)))
        .collect();
    let mut outputs: Vec<WidgetOutput> = Vec::with_capacity(jobs.len());

    thread::scope(|scope| {
        let handles: Vec<_> = jobs
            .into_iter()
            .map(|(name, entry)| {
                scope.spawn(move || {
                    render_widget(cfg, name).map(|output| WidgetOutput {
                        text: output,
                        color: entry.color,
                        no_sep: entry.no_sep,
                    })
                })
            })
            .collect();

        for handle in handles {
            if let Ok(Some(output)) = handle.join() {
                outputs.push(output);
            }
        }
    });

    if outputs.is_empty() {
        return String::new();
    }

    let mut result = String::with_capacity(1024);
    let mut prev_no_sep = false;

    for (i, item) in outputs.iter().enumerate() {
        if i > 0 && !prev_no_sep && !item.no_sep {
            result.push(' ');
        }
        result.push_str(&format!(
            "#[fg={},bg={}]{}",
            tmux_renderer::color_hex_string(color_from_theme(theme, item.color)),
            tmux_renderer::color_hex_string(theme.surface_alt),
            item.text,
        ));
        prev_no_sep = item.no_sep;
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn status_run_produces_empty_output_for_empty_widget_list() {
        let cfg = WidgetConfig {
            theme_name: "hard",
            transparent: false,
            pane_path: ".",
            battery_name: None,
            low_threshold: 20,
            time_format: TimeFormat::H24,
            cache_ttl: 300,
        };
        let output = run(cfg, &[]);
        assert!(output.is_empty());
    }

    #[test]
    fn status_run_handles_unknown_widget_names_gracefully() {
        let cfg = WidgetConfig {
            theme_name: "hard",
            transparent: false,
            pane_path: ".",
            battery_name: None,
            low_threshold: 20,
            time_format: TimeFormat::H24,
            cache_ttl: 300,
        };
        let output = run(cfg, &["nonexistent", "also-fake"]);
        assert!(output.is_empty());
    }
}
