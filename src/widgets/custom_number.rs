/// Glyph tables for each supported number style.
/// Each table maps digits 0-9 to their corresponding Nerd Font / Unicode glyph.
const GLYPHS: &[(&str, &[&str; 10])] = &[
    (
        "arabic",
        &["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"],
    ),
    (
        "fsquare",
        &["󰎡", "󰎤", "󰎧", "󰎪", "󰎭", "󰎱", "󰎳", "󰎶", "󰎹", "󰎼"],
    ),
    (
        "hsquare",
        &["󰎣", "󰎦", "󰎩", "󰎬", "󰎮", "󰎰", "󰎵", "󰎸", "󰎻", "󰎾"],
    ),
    (
        "dsquare",
        &["󰎢", "󰎥", "󰎨", "󰎫", "󰎲", "󰎯", "󰎴", "󰎷", "󰎺", "󰎽"],
    ),
    ("super", &["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]),
    ("sub", &["₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉"]),
    (
        "earabic",
        &["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"],
    ),
];

#[derive(Debug, Eq, PartialEq)]
pub enum CustomNumberError {
    InvalidFormat,
    Usage,
}

/// Formats an ID string using the given style.
/// Each digit is mapped to its corresponding glyph, followed by a space.
/// "hide" returns an empty string.
pub fn format_number(id: &str, style: &str) -> Result<String, CustomNumberError> {
    if style == "hide" {
        return Ok(String::new());
    }

    let glyphs = GLYPHS
        .iter()
        .find(|(name, _)| *name == style)
        .map(|(_, glyphs)| *glyphs)
        .ok_or(CustomNumberError::InvalidFormat)?;

    let mut result = String::with_capacity(id.len() * 4);
    for char in id.bytes() {
        if char.is_ascii_digit() {
            let idx = (char - b'0') as usize;
            if idx < glyphs.len() {
                result.push_str(glyphs[idx]);
                result.push(' ');
            }
        }
    }

    Ok(result)
}

/// CLI entry point: takes positional args [id, style] and returns formatted output.
pub fn run(args: &[&str]) -> Result<String, CustomNumberError> {
    if args.len() < 2 {
        return Err(CustomNumberError::Usage);
    }
    format_number(args[0], args[1])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn format_number_arabic() {
        assert_eq!("4 2 ", format_number("42", "arabic").unwrap());
    }

    #[test]
    fn format_number_hide() {
        assert_eq!("", format_number("123", "hide").unwrap());
    }

    #[test]
    fn format_number_invalid_format() {
        assert_eq!(
            Err(CustomNumberError::InvalidFormat),
            format_number("1", "nope")
        );
    }
}
