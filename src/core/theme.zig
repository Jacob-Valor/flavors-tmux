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
        if (std.mem.eql(u8, key, "background")) return self.background;
        if (std.mem.eql(u8, key, "foreground")) return self.foreground;
        if (std.mem.eql(u8, key, "surface")) return self.surface;
        if (std.mem.eql(u8, key, "surface_alt")) return self.surface_alt;
        if (std.mem.eql(u8, key, "primary")) return self.primary;
        if (std.mem.eql(u8, key, "primary_bright")) return self.primary_bright;
        if (std.mem.eql(u8, key, "on_primary")) return self.on_primary;
        if (std.mem.eql(u8, key, "on_primary_bright")) return self.on_primary_bright;
        if (std.mem.eql(u8, key, "success")) return self.success;
        if (std.mem.eql(u8, key, "success_bright")) return self.success_bright;
        if (std.mem.eql(u8, key, "danger")) return self.danger;
        if (std.mem.eql(u8, key, "danger_bright")) return self.danger_bright;
        if (std.mem.eql(u8, key, "warning")) return self.warning;
        if (std.mem.eql(u8, key, "warning_bright")) return self.warning_bright;
        if (std.mem.eql(u8, key, "info")) return self.info;
        if (std.mem.eql(u8, key, "info_bright")) return self.info_bright;
        if (std.mem.eql(u8, key, "accent")) return self.accent;
        if (std.mem.eql(u8, key, "accent_bright")) return self.accent_bright;
        if (std.mem.eql(u8, key, "emphasis")) return self.emphasis;
        if (std.mem.eql(u8, key, "muted")) return self.muted;
        if (std.mem.eql(u8, key, "forge_github")) return self.forge_github;
        if (std.mem.eql(u8, key, "forge_gitlab")) return self.forge_gitlab;
        if (std.mem.eql(u8, key, "forge_codeberg")) return self.forge_codeberg;
        return null;
    }
};
