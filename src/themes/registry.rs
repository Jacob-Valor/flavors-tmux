use crate::core::theme_loader;
use crate::core::Theme;
use crate::themes::{
    ayu_dark, ayu_light, catppuccin, dracula, everforest, flexoki_dark, flexoki_light, github_dark,
    github_light, hard, kanagawa, light, medium, monokai, monokai_nebula, nord, onedark, rose_pine,
    rose_pine_dawn, soft, solarized_dark, solarized_light, tokyonight,
};

pub const NAMES: &[&str] = &[
    "hard",
    "medium",
    "soft",
    "light",
    "tokyonight",
    "catppuccin",
    "dracula",
    "nord",
    "github_dark",
    "onedark",
    "solarized_dark",
    "solarized_light",
    "monokai",
    "monokai_nebula",
    "github_light",
    "ayu_dark",
    "ayu_light",
    "flexoki_dark",
    "flexoki_light",
    "rose_pine",
    "rose_pine_dawn",
    "everforest",
    "kanagawa",
];

pub const HARD: Theme = hard::THEME;

pub const fn builtin_by_name(name: &str) -> Option<Theme> {
    match name.as_bytes() {
        b"hard" => Some(hard::THEME),
        b"medium" => Some(medium::THEME),
        b"soft" => Some(soft::THEME),
        b"light" => Some(light::THEME),
        b"tokyonight" => Some(tokyonight::THEME),
        b"catppuccin" => Some(catppuccin::THEME),
        b"dracula" => Some(dracula::THEME),
        b"nord" => Some(nord::THEME),
        b"github_dark" => Some(github_dark::THEME),
        b"onedark" => Some(onedark::THEME),
        b"solarized_dark" => Some(solarized_dark::THEME),
        b"solarized_light" => Some(solarized_light::THEME),
        b"monokai" => Some(monokai::THEME),
        b"monokai_nebula" => Some(monokai_nebula::THEME),
        b"github_light" => Some(github_light::THEME),
        b"ayu_dark" => Some(ayu_dark::THEME),
        b"ayu_light" => Some(ayu_light::THEME),
        b"flexoki_dark" => Some(flexoki_dark::THEME),
        b"flexoki_light" => Some(flexoki_light::THEME),
        b"rose_pine" => Some(rose_pine::THEME),
        b"rose_pine_dawn" => Some(rose_pine_dawn::THEME),
        b"everforest" => Some(everforest::THEME),
        b"kanagawa" => Some(kanagawa::THEME),
        _ => None,
    }
}

pub fn by_name(name: &str) -> Theme {
    if let Some(theme) = builtin_by_name(name) {
        return theme;
    }

    theme_loader::custom_theme_path(name)
        .and_then(|path| theme_loader::load_from_file(&path).ok())
        .unwrap_or(HARD)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::{Color, Rgb};

    const WCAG_AA_NORMAL_TEXT_RATIO: f64 = 4.5;
    const WCAG_AA_BOLD_TEXT_RATIO: f64 = 3.0;

    #[derive(Clone, Copy)]
    struct NamedColor {
        name: &'static str,
        color: Color,
    }

    #[derive(Clone, Copy)]
    struct ColorPair {
        foreground: NamedColor,
        background: NamedColor,
        required: bool,
    }

    #[test]
    fn by_name_returns_correct_themes() {
        let hard_theme = by_name("hard");
        assert!(!hard_theme.background.is_default());
        assert_eq!(Some(tokyonight::THEME), builtin_by_name("tokyonight"));
        assert_eq!(Some(nord::THEME), builtin_by_name("nord"));
        assert_eq!(None, builtin_by_name("nonexistent"));
    }

    #[test]
    fn theme_lookup() {
        let theme = hard::THEME;
        assert_eq!(HARD, theme);
        assert_eq!(Some(Color::hex(0x1b1b1b)), theme.lookup("background"));
        assert_eq!(Some(Color::hex(0x83a598)), theme.lookup("primary"));
        assert_eq!(None, theme.lookup("nonexistent"));
    }

    #[test]
    fn contrast_theme_pairs_meet_wcag_aa() {
        for theme_name in NAMES {
            let Some(theme) = builtin_by_name(theme_name) else {
                panic!("built-in theme '{theme_name}' from NAMES was not found");
            };

            for pair in text_color_pairs(theme) {
                let Some(ratio) = contrast_ratio(pair.foreground.color, pair.background.color)
                else {
                    continue;
                };

                if ratio < WCAG_AA_NORMAL_TEXT_RATIO {
                    if pair.required {
                        // Widget text is always bold — the effective requirement is 3:1 per WCAG AA.
                        if ratio < WCAG_AA_BOLD_TEXT_RATIO {
                            panic!(
                                "theme '{theme_name}' color '{}' on '{}' has contrast ratio {ratio:.2}:1, below WCAG AA bold text minimum {WCAG_AA_BOLD_TEXT_RATIO:.1}:1",
                                pair.foreground.name,
                                pair.background.name,
                            );
                        }
                    }
                    eprintln!(
                        "WCAG AA advisory: theme '{theme_name}' color '{}' on '{}' has contrast ratio {ratio:.2}:1",
                        pair.foreground.name,
                        pair.background.name,
                    );
                }
            }
        }
    }

    fn text_color_pairs(theme: Theme) -> Vec<ColorPair> {
        let background_text = [
            named_color("foreground", theme.foreground),
            named_color("emphasis", theme.emphasis),
            named_color("muted", theme.muted),
            named_color("success", theme.success),
            named_color("danger", theme.danger),
            named_color("danger_bright", theme.danger_bright),
            named_color("warning", theme.warning),
            named_color("info", theme.info),
            named_color("info_bright", theme.info_bright),
            named_color("accent", theme.accent),
            named_color("primary", theme.primary),
            named_color("primary_bright", theme.primary_bright),
            named_color("forge_github", theme.forge_github),
            named_color("forge_gitlab", theme.forge_gitlab),
            named_color("forge_codeberg", theme.forge_codeberg),
        ];
        let advisory_background_text = [
            named_color("success_bright", theme.success_bright),
            named_color("accent_bright", theme.accent_bright),
            named_color("on_primary", theme.on_primary),
            named_color("on_primary_bright", theme.on_primary_bright),
        ];
        let surface_text = [
            named_color("success_bright", theme.success_bright),
            named_color("accent_bright", theme.accent_bright),
        ];
        let mut pairs = Vec::new();
        let background = named_color("background", theme.background);
        let surface = named_color("surface", theme.surface);
        let segment_backgrounds = [background, surface];

        for foreground in background_text {
            for background in segment_backgrounds {
                pairs.push(required_pair(foreground, background));
            }
        }
        for foreground in advisory_background_text {
            pairs.push(advisory_pair(foreground, background));
            pairs.push(advisory_pair(foreground, surface));
        }
        for foreground in surface_text {
            pairs.push(required_pair(foreground, surface));
        }
        pairs.push(required_pair(
            named_color("on_primary", theme.on_primary),
            named_color("primary", theme.primary),
        ));
        pairs.push(required_pair(
            named_color("on_primary_bright", theme.on_primary_bright),
            named_color("primary_bright", theme.primary_bright),
        ));

        pairs
    }

    const fn named_color(name: &'static str, color: Color) -> NamedColor {
        NamedColor { name, color }
    }

    fn required_pair(foreground: NamedColor, background: NamedColor) -> ColorPair {
        ColorPair {
            foreground,
            background,
            required: true,
        }
    }

    fn advisory_pair(foreground: NamedColor, background: NamedColor) -> ColorPair {
        ColorPair {
            foreground,
            background,
            required: false,
        }
    }

    fn contrast_ratio(foreground: Color, background: Color) -> Option<f64> {
        match (foreground, background) {
            (Color::Rgb(foreground), Color::Rgb(background)) => {
                let foreground_luminance = relative_luminance(foreground);
                let background_luminance = relative_luminance(background);
                let lighter = foreground_luminance.max(background_luminance);
                let darker = foreground_luminance.min(background_luminance);

                Some((lighter + 0.05) / (darker + 0.05))
            }
            (Color::Default, _)
            | (Color::Basic(_), _)
            | (Color::Palette(_), _)
            | (_, Color::Default)
            | (_, Color::Basic(_))
            | (_, Color::Palette(_)) => None,
        }
    }

    fn relative_luminance(rgb: Rgb) -> f64 {
        0.2126 * linear_srgb_channel(rgb.r)
            + 0.7152 * linear_srgb_channel(rgb.g)
            + 0.0722 * linear_srgb_channel(rgb.b)
    }

    fn linear_srgb_channel(channel: u32) -> f64 {
        let srgb = f64::from(channel) / 255.0;
        if srgb <= 0.039_28 {
            srgb / 12.92
        } else {
            ((srgb + 0.055) / 1.055).powf(2.4)
        }
    }
}
