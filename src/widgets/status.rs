use crate::cli::args::TimeFormat;
use crate::core::Theme;
use crate::tmux_renderer::ThemeHex;
use crate::widgets;
use crate::widgets::status_entries::{color_from_theme, lookup_entry, WidgetColor, WidgetEntry};
use std::thread;

/// Shared config passed to widget rendering functions.
#[derive(Clone, Copy)]
pub struct WidgetConfig<'a> {
    pub theme: Theme,
    pub transparent: bool,
    pub pane_path: &'a str,
    pub battery_name: Option<&'a str>,
    pub low_threshold: u8,
    pub time_format: TimeFormat,
    pub cache_ttl: u64,
    pub separator: &'a str,
}

fn resolve_separator(style: &str) -> &'static str {
    match style {
        "pipe" => "│",
        "chevron" => "〉",
        "arrow" => "▸",
        "slash" => "/",
        "line" => "━",
        "block" => "▏",
        "none" => "",
        _ => " ",
    }
}

fn render_widget(cfg: WidgetConfig<'_>, theme_hex: &ThemeHex, widget_name: &str) -> Option<String> {
    let output = match widget_name {
        "cwd" => widgets::cwd::run_with_theme_hex(cfg.theme, theme_hex, cfg.pane_path),
        "git" => {
            // The porcelain is prefetched once per render (see `run`) so the
            // git widget never spawns its own `git status` — the whole render
            // shares one spawn for the repo.
            let status = widgets::git_status::prefetch_porcelain(cfg.pane_path);
            widgets::git_status::run_with_theme_hex_prefetched(
                cfg.theme,
                theme_hex,
                &status,
                cfg.pane_path,
            )
        }
        "wb-git" => widgets::wb_git_status::run_with_theme_hex(
            cfg.theme,
            theme_hex,
            cfg.pane_path,
            cfg.cache_ttl,
        ),
        "cpu" => widgets::cpu_memory::run_with_theme_hex(cfg.theme, theme_hex),
        "datetime" => widgets::datetime::run_with_theme_hex(cfg.theme, theme_hex, cfg.time_format),
        "battery" => widgets::battery::run_with_theme_hex(
            cfg.theme,
            theme_hex,
            cfg.battery_name,
            cfg.low_threshold,
        ),
        "kubernetes" => widgets::kubernetes::run_with_theme_hex(cfg.theme, theme_hex),
        "gpg-ssh" => widgets::gpg_ssh_agent::run_with_theme_hex(cfg.theme, theme_hex),
        _ => return None,
    };

    if output.is_empty() {
        None
    } else {
        Some(output)
    }
}

/// Assemble the full tmux status-right string from multiple widgets.
/// Each widget output is wrapped with its assigned color on the segment background.
pub fn run(cfg: WidgetConfig<'_>, show_names: &[&str]) -> String {
    let theme = cfg.theme;
    let theme_hex = ThemeHex::from_theme(theme);
    let segment_bg = if cfg.transparent {
        theme.surface_alt
    } else {
        theme.surface
    };

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

    // Most widgets are cache-read + format (~0.2ms); only the forge and
    // git widgets spawn subprocesses. Spawning a thread per widget costs
    // ~10-30µs each and only pays off when several subprocess-backed widgets
    // run concurrently. Batch the cheap widgets inline, parallelize only the
    // ones that actually block on external processes.
    let blocking = ["git", "wb-git"];
    let (blocking_jobs, inline_jobs): (Vec<_>, Vec<_>) = jobs
        .into_iter()
        .partition(|(name, _)| blocking.contains(name));

    for (name, entry) in inline_jobs {
        if let Some(text) = render_widget(cfg, &theme_hex, name) {
            outputs.push(WidgetOutput {
                text: text.trim_end().to_owned(),
                color: entry.color,
                no_sep: entry.no_sep,
            });
        }
    }

    if !blocking_jobs.is_empty() {
        thread::scope(|scope| {
            let handles: Vec<_> = blocking_jobs
                .into_iter()
                .map(|(name, entry)| {
                    let theme_hex_ref = &theme_hex;
                    scope.spawn(move || {
                        render_widget(cfg, theme_hex_ref, name).map(|output| WidgetOutput {
                            text: output,
                            color: entry.color,
                            no_sep: entry.no_sep,
                        })
                    })
                })
                .collect();

            for handle in handles {
                if let Ok(Some(output)) = handle.join() {
                    outputs.push(WidgetOutput {
                        text: output.text.trim_end().to_owned(),
                        color: output.color,
                        no_sep: output.no_sep,
                    });
                }
            }
        });
    }

    if outputs.is_empty() {
        return String::new();
    }

    let sep = resolve_separator(cfg.separator);
    let mut result = String::with_capacity(1024);
    let mut prev_no_sep = false;

    for (i, item) in outputs.iter().enumerate() {
        // Spacing around separators: one space each side for most styles, but
        // the block/line styles sit tight against the widget text.
        let padded = matches!(cfg.separator, "pipe" | "chevron" | "arrow" | "slash");
        let (pad_l, pad_r) = if padded { (" ", " ") } else { ("", "") };

        if i > 0 && !prev_no_sep && !item.no_sep {
            result.push_str(pad_l);
            result.push_str(sep);
            result.push_str(pad_r);
        }

        result.push_str(&format!(
            "#[fg={},bg={}]{}",
            theme_hex.color(color_from_theme(theme, item.color)),
            theme_hex.color(segment_bg),
            item.text,
        ));
        prev_no_sep = item.no_sep;
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::themes;

    #[test]
    fn status_run_produces_empty_output_for_empty_widget_list() {
        let cfg = WidgetConfig {
            theme: themes::HARD,
            transparent: false,
            pane_path: ".",
            battery_name: None,
            low_threshold: 20,
            time_format: TimeFormat::H24,
            cache_ttl: 300,
            separator: "space",
        };
        let output = run(cfg, &[]);
        assert!(output.is_empty());
    }

    #[test]
    fn status_run_handles_unknown_widget_names_gracefully() {
        let cfg = WidgetConfig {
            theme: themes::HARD,
            transparent: false,
            pane_path: ".",
            battery_name: None,
            low_threshold: 20,
            time_format: TimeFormat::H24,
            cache_ttl: 300,
            separator: "space",
        };
        let output = run(cfg, &["nonexistent", "also-fake"]);
        assert!(output.is_empty());
    }

    #[test]
    fn resolve_separator_returns_bare_glyphs() {
        // Separator glyphs are bare; spacing is applied in the assembly loop
        // so block/line styles can sit tight against widget text.
        assert_eq!("〉", resolve_separator("chevron"));
        assert_eq!("│", resolve_separator("pipe"));
        assert_eq!("▸", resolve_separator("arrow"));
        assert_eq!("/", resolve_separator("slash"));
        assert_eq!("━", resolve_separator("line"));
        assert_eq!("▏", resolve_separator("block"));
        assert_eq!("", resolve_separator("none"));
    }
}
