const std = @import("std");
const Theme = @import("theme.zig").Theme;
const hard_theme = @import("../themes/hard.zig").theme;

fn getStringField(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const field = obj.get(key) orelse return null;
    if (field != .string) return null;
    return field.string;
}

fn dupeStringField(allocator: std.mem.Allocator, obj: std.json.ObjectMap, key: []const u8, default: []const u8) ![]const u8 {
    const field = getStringField(obj, key) orelse return default;
    return try allocator.dupe(u8, field);
}

fn isHexDigit(c: u8) bool {
    return switch (c) {
        '0'...'9', 'a'...'f', 'A'...'F' => true,
        else => false,
    };
}

fn isValidColor(value: []const u8) bool {
    if (std.mem.eql(u8, value, "default")) return true;
    if (value.len != 7) return false;
    if (value[0] != '#') return false;
    for (value[1..]) |c| {
        if (!isHexDigit(c)) return false;
    }
    return true;
}

fn loadFromJsonValue(allocator: std.mem.Allocator, value: std.json.Value) !Theme {
    if (value != .object) return error.InvalidThemeFormat;
    const obj = value.object;

    var result = Theme{
        .background = try dupeStringField(allocator, obj, "background", hard_theme.background),
        .foreground = try dupeStringField(allocator, obj, "foreground", hard_theme.foreground),
        .surface = try dupeStringField(allocator, obj, "surface", hard_theme.surface),
        .surface_alt = try dupeStringField(allocator, obj, "surface_alt", hard_theme.surface_alt),
        .primary = try dupeStringField(allocator, obj, "primary", hard_theme.primary),
        .primary_bright = try dupeStringField(allocator, obj, "primary_bright", hard_theme.primary_bright),
        .on_primary = try dupeStringField(allocator, obj, "on_primary", hard_theme.on_primary),
        .on_primary_bright = try dupeStringField(allocator, obj, "on_primary_bright", hard_theme.on_primary_bright),
        .success = try dupeStringField(allocator, obj, "success", hard_theme.success),
        .success_bright = try dupeStringField(allocator, obj, "success_bright", hard_theme.success_bright),
        .danger = try dupeStringField(allocator, obj, "danger", hard_theme.danger),
        .danger_bright = try dupeStringField(allocator, obj, "danger_bright", hard_theme.danger_bright),
        .warning = try dupeStringField(allocator, obj, "warning", hard_theme.warning),
        .info = try dupeStringField(allocator, obj, "info", hard_theme.info),
        .info_bright = try dupeStringField(allocator, obj, "info_bright", hard_theme.info_bright),
        .accent = try dupeStringField(allocator, obj, "accent", hard_theme.accent),
        .accent_bright = try dupeStringField(allocator, obj, "accent_bright", hard_theme.accent_bright),
        .emphasis = try dupeStringField(allocator, obj, "emphasis", hard_theme.emphasis),
        .muted = try dupeStringField(allocator, obj, "muted", hard_theme.muted),
        .forge_github = try dupeStringField(allocator, obj, "forge_github", hard_theme.forge_github),
        .forge_gitlab = try dupeStringField(allocator, obj, "forge_gitlab", hard_theme.forge_gitlab),
        .forge_codeberg = try dupeStringField(allocator, obj, "forge_codeberg", hard_theme.forge_codeberg),
    };

    // Validate all color fields — reject anything that isn't a hex color or "default"
    // to prevent tmux format injection via custom themes
    inline for (@typeInfo(Theme).@"struct".fields) |field| {
        if (!isValidColor(@field(result, field.name))) {
            @field(result, field.name) = try allocator.dupe(u8, @field(hard_theme, field.name));
        }
    }

    return result;
}

pub fn loadFromFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Theme {
    var file_buf: [8192]u8 = undefined;
    const content = std.Io.Dir.readFile(.cwd(), io, path, &file_buf) catch return error.ThemeReadError;

    // Sub-arena isolates the JSON parse tree from the caller's allocator.
    // loadFromJsonValue dupe's theme fields into the caller's allocator,
    // so the caller still owns the returned Theme strings.
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const parsed = try std.json.parseFromSlice(std.json.Value, arena_alloc, content, .{});
    defer parsed.deinit();

    return try loadFromJsonValue(allocator, parsed.value);
}

pub fn customThemePath(allocator: std.mem.Allocator, environ_map: *std.process.Environ.Map, name: []const u8) !?[]u8 {
    if (!isSafeCustomThemeName(name)) return null;
    const home = environ_map.get("HOME") orelse return null;
    return try std.fmt.allocPrint(allocator, "{s}/.config/flavors-tmux/themes/{s}.json", .{ home, name });
}

/// Stack-buffer variant of customThemePath. Writes the path into the provided
/// buffer instead of heap-allocating. Returns null if the name is unsafe or
/// HOME is not set. The returned slice is a sub-slice of the provided buffer.
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

    const theme = try loadFromJsonValue(arena.allocator(), parsed.value);
    try std.testing.expectEqualStrings("#123456", theme.background);
    try std.testing.expectEqualStrings(hard_theme.foreground, theme.foreground);
    try std.testing.expectEqualStrings(hard_theme.surface_alt, theme.surface_alt);
}
