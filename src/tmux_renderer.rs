use std::fmt::{self, Write};

use crate::core::{Color, Rgb, Style};

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
}
