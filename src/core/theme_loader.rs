use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::SystemTime;

use serde::Deserialize;

use crate::core::{Color, Theme};
use crate::themes::hard;

/// In-memory cache of custom themes keyed by file path + mtime.
/// Avoids repeated file I/O when multiple widgets resolve the same
/// custom theme within a single status refresh.
static CUSTOM_THEME_CACHE: Mutex<Option<HashMap<PathBuf, (SystemTime, Theme)>>> = Mutex::new(None);

#[derive(Debug)]
pub enum ThemeLoaderError {
    Read(std::io::Error),
    Json(serde_json::Error),
    #[allow(dead_code)]
    InvalidThemeFormat,
}

impl From<std::io::Error> for ThemeLoaderError {
    fn from(value: std::io::Error) -> Self {
        Self::Read(value)
    }
}

impl From<serde_json::Error> for ThemeLoaderError {
    fn from(value: serde_json::Error) -> Self {
        Self::Json(value)
    }
}

#[derive(Deserialize)]
struct PartialTheme {
    background: Option<String>,
    foreground: Option<String>,
    surface: Option<String>,
    surface_alt: Option<String>,
    primary: Option<String>,
    primary_bright: Option<String>,
    on_primary: Option<String>,
    on_primary_bright: Option<String>,
    success: Option<String>,
    success_bright: Option<String>,
    danger: Option<String>,
    danger_bright: Option<String>,
    warning: Option<String>,
    info: Option<String>,
    info_bright: Option<String>,
    accent: Option<String>,
    accent_bright: Option<String>,
    emphasis: Option<String>,
    muted: Option<String>,
    forge_github: Option<String>,
    forge_gitlab: Option<String>,
    forge_codeberg: Option<String>,
}

fn parse_color_field(value: Option<&str>, default: Color) -> Color {
    let Some(raw) = value else {
        return default;
    };
    if raw == "default" {
        return Color::Default;
    }
    let Some(hex) = raw.strip_prefix('#') else {
        return default;
    };
    if hex.len() != 6 {
        return default;
    }
    match u32::from_str_radix(hex, 16) {
        Ok(value) => Color::hex(value),
        Err(_) => default,
    }
}

fn load_from_partial(partial: &PartialTheme) -> Theme {
    let default = hard::THEME;
    Theme {
        background: parse_color_field(partial.background.as_deref(), default.background),
        foreground: parse_color_field(partial.foreground.as_deref(), default.foreground),
        surface: parse_color_field(partial.surface.as_deref(), default.surface),
        surface_alt: parse_color_field(partial.surface_alt.as_deref(), default.surface_alt),
        primary: parse_color_field(partial.primary.as_deref(), default.primary),
        primary_bright: parse_color_field(
            partial.primary_bright.as_deref(),
            default.primary_bright,
        ),
        on_primary: parse_color_field(partial.on_primary.as_deref(), default.on_primary),
        on_primary_bright: parse_color_field(
            partial.on_primary_bright.as_deref(),
            default.on_primary_bright,
        ),
        success: parse_color_field(partial.success.as_deref(), default.success),
        success_bright: parse_color_field(
            partial.success_bright.as_deref(),
            default.success_bright,
        ),
        danger: parse_color_field(partial.danger.as_deref(), default.danger),
        danger_bright: parse_color_field(partial.danger_bright.as_deref(), default.danger_bright),
        warning: parse_color_field(partial.warning.as_deref(), default.warning),
        info: parse_color_field(partial.info.as_deref(), default.info),
        info_bright: parse_color_field(partial.info_bright.as_deref(), default.info_bright),
        accent: parse_color_field(partial.accent.as_deref(), default.accent),
        accent_bright: parse_color_field(partial.accent_bright.as_deref(), default.accent_bright),
        emphasis: parse_color_field(partial.emphasis.as_deref(), default.emphasis),
        muted: parse_color_field(partial.muted.as_deref(), default.muted),
        forge_github: parse_color_field(partial.forge_github.as_deref(), default.forge_github),
        forge_gitlab: parse_color_field(partial.forge_gitlab.as_deref(), default.forge_gitlab),
        forge_codeberg: parse_color_field(
            partial.forge_codeberg.as_deref(),
            default.forge_codeberg,
        ),
    }
}

pub fn load_from_json_str(content: &str) -> Result<Theme, ThemeLoaderError> {
    let partial: PartialTheme = serde_json::from_str(content)?;
    Ok(load_from_partial(&partial))
}

pub fn load_from_file(path: &Path) -> Result<Theme, ThemeLoaderError> {
    let mtime = path.metadata()?.modified()?;
    if let Ok(cache) = CUSTOM_THEME_CACHE.lock() {
        if let Some(map) = cache.as_ref() {
            if let Some((cached_mtime, cached_theme)) = map.get(path) {
                if *cached_mtime == mtime {
                    return Ok(*cached_theme);
                }
            }
        }
    }
    let content = fs::read_to_string(path)?;
    let theme = load_from_json_str(&content)?;
    if let Ok(mut cache) = CUSTOM_THEME_CACHE.lock() {
        let map = cache.get_or_insert_with(HashMap::new);
        if map.len() > 64 {
            map.clear();
        }
        map.insert(path.to_path_buf(), (mtime, theme));
    }
    Ok(theme)
}

pub fn custom_theme_path(name: &str) -> Option<PathBuf> {
    if !is_safe_custom_theme_name(name) {
        return None;
    }
    let home = env::var_os("HOME")?;
    let mut path = PathBuf::from(home);
    path.push(".config");
    path.push("flavors-tmux");
    path.push("themes");
    path.push(format!("{name}.json"));
    Some(path)
}

pub fn is_safe_custom_theme_name(name: &str) -> bool {
    !name.is_empty()
        && name
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'_' || byte == b'-')
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn custom_theme_names_reject_path_traversal() {
        assert!(is_safe_custom_theme_name("my_theme-1"));
        assert!(!is_safe_custom_theme_name("../hard"));
        assert!(!is_safe_custom_theme_name("nested/theme"));
        assert!(!is_safe_custom_theme_name(""));
    }

    #[test]
    fn custom_themes_fall_back_to_hard_colors_for_missing_keys() -> Result<(), ThemeLoaderError> {
        let theme = load_from_json_str("{\"background\":\"#123456\"}")?;
        assert_eq!(Color::hex(0x123456), theme.background);
        assert_eq!(hard::THEME.foreground, theme.foreground);
        assert_eq!(hard::THEME.surface_alt, theme.surface_alt);
        Ok(())
    }
}
