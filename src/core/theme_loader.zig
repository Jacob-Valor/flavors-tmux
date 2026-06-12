const std = @import("std");
const tui = @import("tui");
const Color = tui.Color;
const Theme = @import("theme.zig").Theme;
const hard_theme = @import("../themes/hard.zig").theme;

fn getStringField(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const field = obj.get(key) orelse return null;
    if (field != .string) return null;
    return field.string;
}

/// Parse a hex color string like "#1b1b1b" into a Color.
/// Returns null for "default" or invalid strings.
fn parseColorField(value: ?[]const u8, default: Color) Color {
    const s = value orelse return default;
    if (std.mem.eql(u8, s, "default")) return .default;
    if (s.len != 7 or s[0] != '#') return default;
    const hex_val = std.fmt.parseInt(u24, s[1..], 16) catch return default;
    return Color.hex(hex_val);
}

fn loadFromJsonValue(value: std.json.Value) !Theme {
    if (value != .object) return error.InvalidThemeFormat;
    const obj = value.object;

    return Theme{
        .background = parseColorField(getStringField(obj, "background"), hard_theme.background),
        .foreground = parseColorField(getStringField(obj, "foreground"), hard_theme.foreground),
        .surface = parseColorField(getStringField(obj, "surface"), hard_theme.surface),
        .surface_alt = parseColorField(getStringField(obj, "surface_alt"), hard_theme.surface_alt),
        .primary = parseColorField(getStringField(obj, "primary"), hard_theme.primary),
        .primary_bright = parseColorField(getStringField(obj, "primary_bright"), hard_theme.primary_bright),
        .on_primary = parseColorField(getStringField(obj, "on_primary"), hard_theme.on_primary),
        .on_primary_bright = parseColorField(getStringField(obj, "on_primary_bright"), hard_theme.on_primary_bright),
        .success = parseColorField(getStringField(obj, "success"), hard_theme.success),
        .success_bright = parseColorField(getStringField(obj, "success_bright"), hard_theme.success_bright),
        .danger = parseColorField(getStringField(obj, "danger"), hard_theme.danger),
        .danger_bright = parseColorField(getStringField(obj, "danger_bright"), hard_theme.danger_bright),
        .warning = parseColorField(getStringField(obj, "warning"), hard_theme.warning),
        .info = parseColorField(getStringField(obj, "info"), hard_theme.info),
        .info_bright = parseColorField(getStringField(obj, "info_bright"), hard_theme.info_bright),
        .accent = parseColorField(getStringField(obj, "accent"), hard_theme.accent),
        .accent_bright = parseColorField(getStringField(obj, "accent_bright"), hard_theme.accent_bright),
        .emphasis = parseColorField(getStringField(obj, "emphasis"), hard_theme.emphasis),
        .muted = parseColorField(getStringField(obj, "muted"), hard_theme.muted),
        .forge_github = parseColorField(getStringField(obj, "forge_github"), hard_theme.forge_github),
        .forge_gitlab = parseColorField(getStringField(obj, "forge_gitlab"), hard_theme.forge_gitlab),
        .forge_codeberg = parseColorField(getStringField(obj, "forge_codeberg"), hard_theme.forge_codeberg),
    };
}

pub fn loadFromFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Theme {
    var file_buf: [8192]u8 = undefined;
    const content = std.Io.Dir.readFile(.cwd(), io, path, &file_buf) catch return error.ThemeReadError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const parsed = try std.json.parseFromSlice(std.json.Value, arena_alloc, content, .{});
    defer parsed.deinit();

    return try loadFromJsonValue(parsed.value);
}

pub fn customThemePath(allocator: std.mem.Allocator, environ_map: *std.process.Environ.Map, name: []const u8) !?[]u8 {
    if (!isSafeCustomThemeName(name)) return null;
    const home = environ_map.get("HOME") orelse return null;
    return try std.fmt.allocPrint(allocator, "{s}/.config/flavors-tmux/themes/{s}.json", .{ home, name });
}

pub fn customThemePathBuf(environ_map: *std.process.Environ.Map, name: []const u8, buf: []u8) !?[]const u8 {
    if (!isSafeCustomThemeName(name)) return null;
    const home = environ_map.get("HOME") orelse return null;
    return try std.fmt.bufPrint(buf, "{s}/.config/flavors-tmux/themes/{s}.json", .{ home, name });
}

pub fn isSafeCustomThemeName(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '_' or c == '-') continue;
        return false;
    }
    return true;
}

test "custom theme names reject path traversal" {
    try std.testing.expect(isSafeCustomThemeName("my_theme-1"));
    try std.testing.expect(!isSafeCustomThemeName("../hard"));
    try std.testing.expect(!isSafeCustomThemeName("nested/theme"));
    try std.testing.expect(!isSafeCustomThemeName(""));
}

test "custom themes fall back to hard colors for missing keys" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const parsed = try std.json.parseFromSlice(std.json.Value, arena.allocator(), "{\"background\":\"#123456\"}", .{});
    defer parsed.deinit();

    const theme = try loadFromJsonValue(parsed.value);
    try std.testing.expect(std.meta.eql(Color.hex(0x123456), theme.background));
    try std.testing.expect(std.meta.eql(hard_theme.foreground, theme.foreground));
    try std.testing.expect(std.meta.eql(hard_theme.surface_alt, theme.surface_alt));
}
