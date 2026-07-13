use std::borrow::Cow;
use std::fmt::{self, Write};

use crate::core::{BasicColor, Color, Rgb, Style, Theme};

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ThemeHex {
    theme: Theme,
    pub background: String,
    pub foreground: String,
    pub surface: String,
    pub surface_alt: String,
    pub primary: String,
    pub primary_bright: String,
    pub on_primary: String,
    pub on_primary_bright: String,
    pub success: String,
    pub success_bright: String,
    pub danger: String,
    pub danger_bright: String,
    pub warning: String,
    pub info: String,
    pub info_bright: String,
    pub accent: String,
    pub accent_bright: String,
    pub emphasis: String,
    pub muted: String,
    pub forge_github: String,
    pub forge_gitlab: String,
    pub forge_codeberg: String,
}

impl ThemeHex {
    pub fn from_theme(theme: Theme) -> Self {
        Self {
            theme,
            background: color_hex_string(theme.background),
            foreground: color_hex_string(theme.foreground),
            surface: color_hex_string(theme.surface),
            surface_alt: color_hex_string(theme.surface_alt),
            primary: color_hex_string(theme.primary),
            primary_bright: color_hex_string(theme.primary_bright),
            on_primary: color_hex_string(theme.on_primary),
            on_primary_bright: color_hex_string(theme.on_primary_bright),
            success: color_hex_string(theme.success),
            success_bright: color_hex_string(theme.success_bright),
            danger: color_hex_string(theme.danger),
            danger_bright: color_hex_string(theme.danger_bright),
            warning: color_hex_string(theme.warning),
            info: color_hex_string(theme.info),
            info_bright: color_hex_string(theme.info_bright),
            accent: color_hex_string(theme.accent),
            accent_bright: color_hex_string(theme.accent_bright),
            emphasis: color_hex_string(theme.emphasis),
            muted: color_hex_string(theme.muted),
            forge_github: color_hex_string(theme.forge_github),
            forge_gitlab: color_hex_string(theme.forge_gitlab),
            forge_codeberg: color_hex_string(theme.forge_codeberg),
        }
    }

    pub fn color(&self, color: Color) -> Cow<'_, str> {
        if color == self.theme.background {
            Cow::Borrowed(&self.background)
        } else if color == self.theme.foreground {
            Cow::Borrowed(&self.foreground)
        } else if color == self.theme.surface {
            Cow::Borrowed(&self.surface)
        } else if color == self.theme.surface_alt {
            Cow::Borrowed(&self.surface_alt)
        } else if color == self.theme.primary {
            Cow::Borrowed(&self.primary)
        } else if color == self.theme.primary_bright {
            Cow::Borrowed(&self.primary_bright)
        } else if color == self.theme.on_primary {
            Cow::Borrowed(&self.on_primary)
        } else if color == self.theme.on_primary_bright {
            Cow::Borrowed(&self.on_primary_bright)
        } else if color == self.theme.success {
            Cow::Borrowed(&self.success)
        } else if color == self.theme.success_bright {
            Cow::Borrowed(&self.success_bright)
        } else if color == self.theme.danger {
            Cow::Borrowed(&self.danger)
        } else if color == self.theme.danger_bright {
            Cow::Borrowed(&self.danger_bright)
        } else if color == self.theme.warning {
            Cow::Borrowed(&self.warning)
        } else if color == self.theme.info {
            Cow::Borrowed(&self.info)
        } else if color == self.theme.info_bright {
            Cow::Borrowed(&self.info_bright)
        } else if color == self.theme.accent {
            Cow::Borrowed(&self.accent)
        } else if color == self.theme.accent_bright {
            Cow::Borrowed(&self.accent_bright)
        } else if color == self.theme.emphasis {
            Cow::Borrowed(&self.emphasis)
        } else if color == self.theme.muted {
            Cow::Borrowed(&self.muted)
        } else if color == self.theme.forge_github {
            Cow::Borrowed(&self.forge_github)
        } else if color == self.theme.forge_gitlab {
            Cow::Borrowed(&self.forge_gitlab)
        } else if color == self.theme.forge_codeberg {
            Cow::Borrowed(&self.forge_codeberg)
        } else {
            match color {
                Color::Default => Cow::Borrowed("default"),
                Color::Basic(basic) => Cow::Borrowed(basic_color_hex(basic)),
                Color::Rgb(_) | Color::Palette(_) => Cow::Owned(color_hex_string(color)),
            }
        }
    }
}

pub fn write_style(style: Style, writer: &mut impl Write) -> fmt::Result {
    let mut started = false;

    macro_rules! flush_prefix {
        () => {{
            if !started {
                writer.write_str("#[")?;
                started = true;
            } else {
                writer.write_char(',')?;
            }
        }};
    }

    match style.fg {
        Color::Default => {}
        color => {
            flush_prefix!();
            write!(writer, "fg={}", color_hex_string(color))?;
        }
    }

    match style.bg {
        Color::Default => {}
        color => {
            flush_prefix!();
            write!(writer, "bg={}", color_hex_string(color))?;
        }
    }

    macro_rules! write_attr {
        ($attr:ident, $label:expr) => {
            if style.attrs.$attr {
                flush_prefix!();
                writer.write_str($label)?;
            }
        };
    }

    write_attr!(bold, "bold");
    write_attr!(dim, "dim");
    write_attr!(italic, "italic");
    write_attr!(underline, "underscore");
    write_attr!(blink, "blink");
    write_attr!(reverse, "reverse");
    write_attr!(strikethrough, "strikethrough");
    write_attr!(hidden, "hidden");

    if started {
        writer.write_char(']')?;
    }
    Ok(())
}

pub fn write_reset(fg: Color, bg: Color, writer: &mut impl Write) -> fmt::Result {
    write!(
        writer,
        "#[fg={},bg={},nobold,noitalics,nounderscore,nodim]",
        color_hex_string(fg),
        color_hex_string(bg)
    )
}

pub fn reset_string(fg: Color, bg: Color) -> String {
    format!(
        "#[fg={},bg={},nobold,noitalics,nounderscore,nodim]",
        color_hex_string(fg),
        color_hex_string(bg)
    )
}

pub fn color_hex_string(color: Color) -> String {
    match color {
        Color::Default => String::from("default"),
        Color::Rgb(rgb) => rgb_hex_string(rgb),
        Color::Basic(basic) => format!("colour{}", basic.tmux_index()),
        Color::Palette(palette) => format!("colour{palette}"),
    }
}

const fn basic_color_hex(color: BasicColor) -> &'static str {
    match color {
        BasicColor::Black => "colour0",
        BasicColor::Red => "colour1",
        BasicColor::Green => "colour2",
        BasicColor::Yellow => "colour3",
        BasicColor::Blue => "colour4",
        BasicColor::Magenta => "colour5",
        BasicColor::Cyan => "colour6",
        BasicColor::White => "colour7",
    }
}

fn rgb_hex_string(rgb: Rgb) -> String {
    format!("#{:02x}{:02x}{:02x}", rgb.r, rgb.g, rgb.b)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn write_reset_produces_correct_tmux_format() -> fmt::Result {
        let mut output = String::new();
        write_reset(Color::hex(0x1b1b1b), Color::hex(0xfbf1c7), &mut output)?;
        assert!(output.starts_with("#[fg=#1b1b1b,bg=#fbf1c7"));
        assert!(output.contains("nobold"));
        assert!(output.contains("noitalics"));
        Ok(())
    }

    #[test]
    fn write_style_handles_bold_italic_fg_in_combined_format() -> fmt::Result {
        let mut output = String::new();
        let style = Style::DEFAULT.set_fg(Color::hex(0x3fb950)).bold().italic();
        write_style(style, &mut output)?;
        assert_eq!("#[fg=#3fb950,bold,italic]", output);
        Ok(())
    }

    #[test]
    fn write_style_handles_fg_bg_dim() -> fmt::Result {
        let mut output = String::new();
        let style = Style::DEFAULT
            .set_fg(Color::hex(0xfbf1c7))
            .set_bg(Color::hex(0x1b1b1b))
            .dim();
        write_style(style, &mut output)?;
        assert_eq!("#[fg=#fbf1c7,bg=#1b1b1b,dim]", output);
        Ok(())
    }

    #[test]
    fn write_style_empty_style_writes_nothing() -> fmt::Result {
        let mut output = String::new();
        write_style(Style::DEFAULT, &mut output)?;
        assert_eq!("", output);
        Ok(())
    }

    #[test]
    fn color_hex_string_formats_correctly() {
        assert_eq!("#1b1b1b", color_hex_string(Color::hex(0x1b1b1b)));
        assert_eq!("default", color_hex_string(Color::Default));
    }

    #[test]
    fn theme_hex_reuses_precomputed_theme_color_strings() {
        let theme = crate::themes::hard::THEME;
        let hex = ThemeHex::from_theme(theme);

        assert_eq!("#1b1b1b", hex.color(theme.background));
        assert_eq!("#fbf1c7", hex.color(theme.foreground));
        assert_eq!("default", hex.color(Color::Default));
        assert_eq!("colour1", hex.color(Color::Basic(BasicColor::Red)));
    }
}
