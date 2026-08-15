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
    // Position-indexed so parallel results land in their requested slot —
    // otherwise blocking widgets (git/forge) would always render last.
    let mut outputs: Vec<Option<WidgetOutput>> = (0..jobs.len()).map(|_| None).collect();

    // Most widgets are cache-read + format (~0.2ms); only the forge and
    // git widgets spawn subprocesses. Spawning a thread per widget costs
    // ~10-30µs each and only pays off when several subprocess-backed widgets
    // run concurrently. Batch the cheap widgets inline, parallelize only the
    // ones that actually block on external processes.
    let blocking = ["git", "wb-git"];
    let mut blocking_slots: Vec<usize> = Vec::new();

    for (i, (name, entry)) in jobs.iter().enumerate() {
        if blocking.contains(name) {
            blocking_slots.push(i);
            continue;
        }
        if let Some(text) = render_widget(cfg, &theme_hex, name) {
            outputs[i] = Some(WidgetOutput {
                text: text.trim_end().to_owned(),
                color: entry.color,
                no_sep: entry.no_sep,
            });
        }
    }

    if !blocking_slots.is_empty() {
        thread::scope(|scope| {
            let handles: Vec<_> = blocking_slots
                .iter()
                .map(|&slot| {
                    let (name, entry) = jobs[slot];
                    let theme_hex_ref = &theme_hex;
                    scope.spawn(move || {
                        let out = render_widget(cfg, theme_hex_ref, name).map(|text| {
                            WidgetOutput {
                                text: text.trim_end().to_owned(),
                                color: entry.color,
                                no_sep: entry.no_sep,
                            }
                        });
                        (slot, out)
                    })
                })
                .collect();

            for handle in handles {
                if let Ok((slot, Some(output))) = handle.join() {
                    outputs[slot] = Some(output);
                }
            }
        });
    }

    // Drop empty slots, preserving the requested relative order.
    let outputs: Vec<WidgetOutput> = outputs.into_iter().flatten().collect();
    if outputs.is_empty() {
        return String::new();
    }

    let sep = resolve_separator(cfg.separator);
    // "space" and "none" separators emit no glyph — the per-segment padding
    // provides the inter-segment gap. Glyph separators (pipe/chevron/arrow/
    // slash/line/block) sit between the padded segments, one space each side
    // from the padding.
    let sep_glyph = if matches!(cfg.separator, "space" | "none") {
        ""
    } else {
        sep
    };
    let mut result = String::with_capacity(1024);
    let mut prev_no_sep = false;

    for (i, item) in outputs.iter().enumerate() {
        let is_last = i + 1 == outputs.len();
        // no_sep widgets (forge) attach to the previous segment — no
        // glyph and no gap before them.
        let next_no_sep = outputs.get(i + 1).map(|n| n.no_sep).unwrap_or(false);

        if i > 0 && !prev_no_sep && !item.no_sep {
            result.push_str(sep_glyph);
        }

        // Each widget is its own segment on the segment background. One
        // trailing space pads the segment so widgets read as distinct blocks
        // instead of a run-on blob; the last segment omits it so the bar's
        // right edge stays clean (a padded space would paint a segment-bg
        // cell at the window edge).
        result.push_str(&format!(
            "#[fg={},bg={}]{}",
            theme_hex.color(color_from_theme(theme, item.color)),
            theme_hex.color(segment_bg),
            item.text,
        ));
        if !is_last && !next_no_sep {
            result.push(' ');
        }
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

    #[test]
    fn segments_are_padded_and_separated() {
        // cpu (no_sep=false) and datetime (no_sep=false): the default
        // space separator emits no glyph; the per-segment padding provides
        // the gap, and the last segment has no trailing space.
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
        let output = run(cfg, &["cpu", "datetime"]);
        // cpu and datetime both render. Assert the structural
        // properties: each segment is wrapped in fg/bg, exactly one space
        // separates them, and the output does not end with a space.
        assert!(output.contains("#[fg="));
        assert!(output.contains("bg="));
        assert!(!output.ends_with(' '));
        // The cpu segment's padding space sits before the datetime
        // segment's fg wrapper — the cpu text (the mem `%` value) is
        // followed by " " then a fresh "#[fg=".
        assert!(
            output.contains(" #[fg="),
            "segment padding space must precede the next segment wrapper: {output}"
        );
        // datetime (the last segment) has no trailing padding space — the
        // output must not end with a space.
        assert!(!output.ends_with(' '));
    }

    #[test]
    fn all_widgets_are_separate_segments() {
        // git and wb-git are both normal (no_sep=false) segments — the forge
        // widget renders with a space gap after the git segment, like every
        // other widget.
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
        let output = run(cfg, &["git", "wb-git"]);
        // In this repo both render; the forge header (muted icon) must sit
        // in its own segment after the git text.
        if output.contains("󱓎") && output.contains("") {
            let git_end = output.find("󱓎").unwrap();
            let forge_start = output.find("").unwrap();
            assert!(
                forge_start > git_end,
                "forge should come after git sync icon"
            );
            // The git segment's padding space sits before the forge segment's
            // outer wrapper (fg=accent,bg=surface), separating the two.
            let git_text_end = output.find("#[fg=#d3869b,bg=#282828]").unwrap();
            assert!(
                output[..git_text_end].ends_with(' '),
                "git segment must end with a padding space: '{output}'"
            );
        }
    }
}
