use crate::cli::args::TimeFormat;
use crate::themes;
use crate::tmux_renderer;
use crate::widgets;
use crate::widgets::status_entries::{color_from_theme, lookup_entry, WidgetColor, WidgetEntry};
use std::thread;

fn render_widget(
    theme_name: &str,
    transparent: bool,
    pane_path: &str,
    widget_name: &str,
    battery_name: Option<&str>,
    low_threshold: u8,
    time_format: TimeFormat,
    cache_ttl: u64,
) -> Option<String> {
    let output = match widget_name {
        "cwd" => widgets::cwd::run(theme_name, transparent, pane_path),
        "git" => widgets::git_status::run(theme_name, transparent, pane_path),
        "wb-git" => widgets::wb_git_status::run(theme_name, transparent, pane_path, cache_ttl),
        "cpu" => widgets::cpu_memory::run(theme_name, transparent),
        "hostname" => widgets::hostname::run(theme_name, transparent),
        "datetime" => widgets::datetime::run(theme_name, time_format, transparent),
        "battery" => widgets::battery::run(theme_name, transparent, battery_name, low_threshold),
        "kubernetes" => widgets::kubernetes::run(theme_name, transparent),
        "terraform" => widgets::terraform::run(theme_name, transparent, pane_path),
        "docker" => widgets::docker::run(theme_name, transparent),
        "yadm" => widgets::yadm::run(theme_name, transparent),
        "gpg-ssh" => widgets::gpg_ssh_agent::run(theme_name, transparent),
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
    theme_name: &str,
    transparent: bool,
    pane_path: Option<&str>,
    show_names: &[&str],
    battery_name: Option<&str>,
    low_threshold: u8,
    time_format: TimeFormat,
    cache_ttl: u64,
) -> String {
    let theme = themes::by_name(theme_name).with_transparent_background(transparent);
    let path = pane_path.unwrap_or(".");

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
                    render_widget(
                        theme_name,
                        transparent,
                        path,
                        name,
                        battery_name,
                        low_threshold,
                        time_format,
                        cache_ttl,
                    )
                    .map(|output| WidgetOutput {
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
        let output = run("hard", false, None, &[], None, 20, TimeFormat::H24, 300);
        assert!(output.is_empty());
    }

    #[test]
    fn status_run_handles_unknown_widget_names_gracefully() {
        let output = run(
            "hard",
            false,
            None,
            &["nonexistent", "also-fake"],
            None,
            20,
            TimeFormat::H24,
            300,
        );
        assert!(output.is_empty());
    }
}
