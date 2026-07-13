use crate::core::{Color, Theme};
use crate::themes;
use crate::tmux_renderer::ThemeHex;

#[derive(Clone, Debug)]
pub struct WidgetContext {
    pub theme: Theme,
    pub reset: String,
}

impl WidgetContext {
    pub fn new(theme_name: &str, transparent: bool) -> Self {
        let theme = themes::by_name(theme_name).with_transparent_background(transparent);
        let theme_hex = ThemeHex::from_theme(theme);
        Self::from_theme_hex(theme, &theme_hex)
    }

    pub fn from_theme(theme: Theme) -> Self {
        let theme_hex = ThemeHex::from_theme(theme);
        Self::from_theme_hex(theme, &theme_hex)
    }

    pub fn from_theme_hex(theme: Theme, theme_hex: &ThemeHex) -> Self {
        let reset = format!(
            "#[fg={},bg={},nobold,noitalics,nounderscore,nodim]",
            theme_hex.color(theme.foreground),
            theme_hex.color(theme.background),
        );
        Self { theme, reset }
    }

    pub const fn threshold_color(&self, percent: u8) -> Color {
        if percent >= 80 {
            self.theme.danger
        } else if percent >= 50 {
            self.theme.warning
        } else {
            self.theme.success
        }
    }

    pub const fn battery_color(&self, percentage: u8, low_threshold: u8) -> Color {
        if percentage < low_threshold {
            self.theme.danger
        } else if percentage >= 100 {
            self.theme.success
        } else {
            self.theme.warning
        }
    }

    pub fn format_segment(
        &self,
        theme_hex: &ThemeHex,
        color: Color,
        icon: &str,
        value: usize,
    ) -> String {
        format!(
            " {}#[fg={},bg={},bold]{} {}",
            self.reset,
            theme_hex.color(color),
            theme_hex.color(self.theme.background),
            icon,
            value
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn widget_context_threshold_color() {
        let ctx = WidgetContext::new("hard", false);
        assert_eq!(ctx.theme.danger, ctx.threshold_color(80));
        assert_eq!(ctx.theme.danger, ctx.threshold_color(100));
        assert_eq!(ctx.theme.warning, ctx.threshold_color(50));
        assert_eq!(ctx.theme.warning, ctx.threshold_color(79));
        assert_eq!(ctx.theme.success, ctx.threshold_color(49));
        assert_eq!(ctx.theme.success, ctx.threshold_color(0));
    }

    #[test]
    fn widget_context_battery_color() {
        let ctx = WidgetContext::new("hard", false);
        assert_eq!(ctx.theme.danger, ctx.battery_color(10, 20));
        assert_eq!(ctx.theme.warning, ctx.battery_color(50, 20));
        assert_eq!(ctx.theme.success, ctx.battery_color(100, 20));
    }

    #[test]
    fn widget_context_format_segment() {
        let ctx = WidgetContext::new("hard", false);
        let theme_hex = ThemeHex::from_theme(ctx.theme);
        let segment = ctx.format_segment(&theme_hex, ctx.theme.success, "󰍛", 42);
        assert!(segment.contains("#[fg="));
        assert!(segment.contains("󰍛"));
        assert!(segment.contains("42"));
    }
}
