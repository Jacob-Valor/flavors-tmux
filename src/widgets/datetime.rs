use crate::cli::args::TimeFormat;
use crate::core::Theme;
use crate::tmux_renderer;

fn format_24h(hour: u32, minute: u32) -> String {
    format!("{hour:02}:{minute:02} ")
}

fn format_12h(hour: u32, minute: u32) -> String {
    let is_pm = hour >= 12;
    let display_hour = match hour {
        0 => 12,
        13..=23 => hour - 12,
        _ => hour,
    };
    let suffix = if is_pm { "PM" } else { "AM" };
    format!("{display_hour:02}:{minute:02} {suffix} ")
}

fn local_time() -> time::Time {
    time::OffsetDateTime::now_local()
        .unwrap_or_else(|_| time::OffsetDateTime::now_utc())
        .time()
}

fn format_time(time_format: TimeFormat, time: time::Time) -> String {
    match time_format {
        TimeFormat::H12 => format_12h(u32::from(time.hour()), u32::from(time.minute())),
        TimeFormat::H24 => format_24h(u32::from(time.hour()), u32::from(time.minute())),
        TimeFormat::Hide => String::new(),
    }
}

/// Render the datetime widget with a configurable 12H/24H/hide format.
pub fn run(theme: Theme, time_format: TimeFormat) -> String {
    let time_str = format_time(time_format, local_time());
    if time_str.is_empty() {
        return String::new();
    }

    let separator = "▒";
    let time_icon = "󰥔";

    format!(
        "#[fg={},bg={}]{} #[fg={}]{} {}",
        tmux_renderer::color_hex_string(theme.accent),
        tmux_renderer::color_hex_string(theme.surface_alt),
        separator,
        tmux_renderer::color_hex_string(theme.emphasis),
        time_icon,
        time_str,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn format_24h_produces_hh_colon_mm_space() {
        assert_eq!("09:05 ", format_24h(9, 5));
        assert_eq!("23:59 ", format_24h(23, 59));
        assert_eq!("00:00 ", format_24h(0, 0));
    }

    #[test]
    fn format_12h_produces_hh_colon_mm_am_pm_space() {
        assert_eq!("12:00 AM ", format_12h(0, 0));
        assert_eq!("12:30 PM ", format_12h(12, 30));
        assert_eq!("03:45 PM ", format_12h(15, 45));
        assert_eq!("11:59 PM ", format_12h(23, 59));
    }

    #[test]
    fn format_time_hides_time_text() {
        let time = time::Time::from_hms(9, 5, 0).unwrap();
        assert_eq!("", format_time(TimeFormat::Hide, time));
    }
}
