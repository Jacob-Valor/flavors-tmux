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
    use crate::core::Color;

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
}
