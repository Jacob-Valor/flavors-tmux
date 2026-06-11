const std = @import("std");
const tui = @import("tui");

pub const Color = tui.Color;

pub const Theme = struct {
    background: Color,
    foreground: Color,
    surface: Color,
    surface_alt: Color,
    primary: Color,
    primary_bright: Color,
    on_primary: Color,
    on_primary_bright: Color,
    success: Color,
    success_bright: Color,
    danger: Color,
    danger_bright: Color,
    warning: Color,
    info: Color,
    info_bright: Color,
    accent: Color,
    accent_bright: Color,
    emphasis: Color,
    muted: Color,
    forge_github: Color,
    forge_gitlab: Color,
    forge_codeberg: Color,

    pub fn withTransparentBackground(self: Theme, enabled: bool) Theme {
        var theme = self;
        if (enabled) {
            theme.background = .default;
            theme.surface_alt = .default;
        }
        return theme;
    }

    pub fn lookup(self: Theme, key: []const u8) ?Color {
        inline for (comptime std.meta.fieldNames(Theme)) |field_name| {
            if (std.mem.eql(u8, key, field_name)) {
                return @field(self, field_name);
            }
        }
        return null;
    }
};
