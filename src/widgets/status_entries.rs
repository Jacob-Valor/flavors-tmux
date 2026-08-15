use crate::core::{Color, Theme};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) enum WidgetColor {
    Emphasis,
    Success,
    Accent,
    Info,
    Danger,
    AccentBright,
    PrimaryBright,
    Warning,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) struct WidgetEntry {
    pub(crate) color: WidgetColor,
    pub(crate) no_sep: bool,
}

const WIDGET_ENTRIES: &[(&str, WidgetEntry)] = &[
    (
        "cwd",
        WidgetEntry {
            color: WidgetColor::Emphasis,
            no_sep: false,
        },
    ),
    (
        "git",
        WidgetEntry {
            color: WidgetColor::Success,
            no_sep: false,
        },
    ),
    (
        "wb-git",
        WidgetEntry {
            color: WidgetColor::Accent,
            no_sep: false,
        },
    ),
    (
        "battery",
        WidgetEntry {
            color: WidgetColor::Danger,
            no_sep: false,
        },
    ),
    (
        "cpu",
        WidgetEntry {
            color: WidgetColor::AccentBright,
            no_sep: false,
        },
    ),
    (
        "kubernetes",
        WidgetEntry {
            color: WidgetColor::Info,
            no_sep: false,
        },
    ),
    (
        "gpg-ssh",
        WidgetEntry {
            color: WidgetColor::PrimaryBright,
            no_sep: false,
        },
    ),
    (
        "datetime",
        WidgetEntry {
            color: WidgetColor::Warning,
            no_sep: false,
        },
    ),
];

pub(crate) fn lookup_entry(name: &str) -> Option<WidgetEntry> {
    WIDGET_ENTRIES
        .iter()
        .find_map(|(entry_name, entry)| (*entry_name == name).then_some(*entry))
}

pub(crate) fn color_from_theme(theme: Theme, wc: WidgetColor) -> Color {
    match wc {
        WidgetColor::Emphasis => theme.emphasis,
        WidgetColor::Success => theme.success,
        WidgetColor::Accent => theme.accent,
        WidgetColor::Info => theme.info,
        WidgetColor::Danger => theme.danger,
        WidgetColor::AccentBright => theme.accent_bright,
        WidgetColor::PrimaryBright => theme.primary_bright,
        WidgetColor::Warning => theme.warning,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::themes;

    #[test]
    fn lookup_entry_returns_correct_colors_for_all_widget_names() {
        let cases = [
            ("cwd", WidgetColor::Emphasis, false),
            ("git", WidgetColor::Success, false),
            ("wb-git", WidgetColor::Accent, false),
            ("battery", WidgetColor::Danger, false),
            ("cpu", WidgetColor::AccentBright, false),
            ("kubernetes", WidgetColor::Info, false),
            ("gpg-ssh", WidgetColor::PrimaryBright, false),
            ("datetime", WidgetColor::Warning, false),
        ];

        for (name, color, no_sep) in cases {
            let entry = lookup_entry(name).expect("widget should have an entry");
            assert_eq!(color, entry.color);
            assert_eq!(no_sep, entry.no_sep);
        }

        assert_eq!(None, lookup_entry("nonexistent"));
    }

    #[test]
    fn color_from_theme_maps_widget_color_to_correct_theme_fields() {
        let theme = themes::hard::THEME;
        assert_eq!(
            theme.emphasis,
            color_from_theme(theme, WidgetColor::Emphasis)
        );
        assert_eq!(theme.success, color_from_theme(theme, WidgetColor::Success));
        assert_eq!(theme.accent, color_from_theme(theme, WidgetColor::Accent));
        assert_eq!(theme.info, color_from_theme(theme, WidgetColor::Info));
        assert_eq!(theme.danger, color_from_theme(theme, WidgetColor::Danger));
        assert_eq!(
            theme.accent_bright,
            color_from_theme(theme, WidgetColor::AccentBright)
        );
        assert_eq!(
            theme.primary_bright,
            color_from_theme(theme, WidgetColor::PrimaryBright)
        );
        assert_eq!(theme.warning, color_from_theme(theme, WidgetColor::Warning));
    }
}
