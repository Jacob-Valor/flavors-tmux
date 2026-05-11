const std = @import("std");
const Theme = @import("theme.zig").Theme;

fn getStringField(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const field = obj.get(key) orelse return null;
    if (field != .string) return null;
    return field.string;
}

fn loadFromJsonValue(_: std.mem.Allocator, value: std.json.Value) !Theme {
    if (value != .object) return error.InvalidThemeFormat;
    const obj = value.object;

    const default = Theme{
        .background = "#000000",
        .foreground = "#ffffff",
        .surface = "#111111",
        .surface_alt = "#000000",
        .primary = "#0088ff",
        .primary_bright = "#44aaff",
        .on_primary = "#000000",
        .on_primary_bright = "#000000",
        .success = "#00ff00",
        .success_bright = "#44ff44",
        .danger = "#ff0000",
        .danger_bright = "#ff4444",
        .warning = "#ffaa00",
        .warning_bright = "#ffcc44",
        .info = "#00aaff",
        .info_bright = "#44ccff",
        .accent = "#ff00ff",
        .accent_bright = "#ff44ff",
        .emphasis = "#ffffff",
        .muted = "#888888",
        .forge_github = "#ffffff",
        .forge_gitlab = "#fc6d26",
        .forge_codeberg = "#fc6d26",
    };

    return Theme{
        .background = getStringField(obj, "background") orelse default.background,
        .foreground = getStringField(obj, "foreground") orelse default.foreground,
        .surface = getStringField(obj, "surface") orelse default.surface,
        .surface_alt = getStringField(obj, "surface_alt") orelse default.surface_alt,
        .primary = getStringField(obj, "primary") orelse default.primary,
        .primary_bright = getStringField(obj, "primary_bright") orelse default.primary_bright,
        .on_primary = getStringField(obj, "on_primary") orelse default.on_primary,
        .on_primary_bright = getStringField(obj, "on_primary_bright") orelse default.on_primary_bright,
        .success = getStringField(obj, "success") orelse default.success,
        .success_bright = getStringField(obj, "success_bright") orelse default.success_bright,
        .danger = getStringField(obj, "danger") orelse default.danger,
        .danger_bright = getStringField(obj, "danger_bright") orelse default.danger_bright,
        .warning = getStringField(obj, "warning") orelse default.warning,
        .warning_bright = getStringField(obj, "warning_bright") orelse default.warning_bright,
        .info = getStringField(obj, "info") orelse default.info,
        .info_bright = getStringField(obj, "info_bright") orelse default.info_bright,
        .accent = getStringField(obj, "accent") orelse default.accent,
        .accent_bright = getStringField(obj, "accent_bright") orelse default.accent_bright,
        .emphasis = getStringField(obj, "emphasis") orelse default.emphasis,
        .muted = getStringField(obj, "muted") orelse default.muted,
        .forge_github = getStringField(obj, "forge_github") orelse default.forge_github,
        .forge_gitlab = getStringField(obj, "forge_gitlab") orelse default.forge_gitlab,
        .forge_codeberg = getStringField(obj, "forge_codeberg") orelse default.forge_codeberg,
    };
}

pub fn loadFromFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Theme {
    var buf: [8192]u8 = undefined;
    const content = std.Io.Dir.readFile(.cwd(), io, path, &buf) catch return error.ThemeReadError;

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{});
    defer parsed.deinit();

    return try loadFromJsonValue(allocator, parsed.value);
}

pub fn customThemePath(allocator: std.mem.Allocator, environ_map: *std.process.Environ.Map, name: []const u8) !?[]u8 {
    const home = environ_map.get("HOME") orelse return null;
    return try std.fmt.allocPrint(allocator, "{s}/.config/flavors-tmux/themes/{s}.json", .{ home, name });
}
