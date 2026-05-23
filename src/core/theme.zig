const std = @import("std");

pub const Theme = struct {
    background: []const u8,
    foreground: []const u8,
    surface: []const u8,
    surface_alt: []const u8,
    primary: []const u8,
    primary_bright: []const u8,
    on_primary: []const u8,
    on_primary_bright: []const u8,
    success: []const u8,
    success_bright: []const u8,
    danger: []const u8,
    danger_bright: []const u8,
    warning: []const u8,
    warning_bright: []const u8,
    info: []const u8,
    info_bright: []const u8,
    accent: []const u8,
    accent_bright: []const u8,
    emphasis: []const u8,
    muted: []const u8,
    forge_github: []const u8,
    forge_gitlab: []const u8,
    forge_codeberg: []const u8,

    pub fn withTransparentBackground(self: Theme, enabled: bool) Theme {
        var theme = self;
        if (enabled) {
            theme.background = "default";
            theme.surface_alt = "default";
        }
        return theme;
    }

    pub fn lookup(self: Theme, key: []const u8) ?[]const u8 {
        inline for (comptime std.meta.fieldNames(Theme)) |field_name| {
            if (std.mem.eql(u8, key, field_name)) {
                return @field(self, field_name);
            }
        }
        return null;
    }
};
