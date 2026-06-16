const std = @import("std");
const tui = @import("tui");
const Theme = @import("../core/theme.zig").Theme;
const theme_loader = @import("../core/theme_loader.zig");

const log = std.log.scoped(.themes);

/// Single source of truth: every theme appears here once.
/// `names`, `byName()`, and any future theme iteration derive from this array.
const builtin_themes = [_]struct { name: []const u8, theme: Theme }{
    .{ .name = "hard", .theme = @import("hard.zig").theme },
    .{ .name = "medium", .theme = @import("medium.zig").theme },
    .{ .name = "soft", .theme = @import("soft.zig").theme },
    .{ .name = "light", .theme = @import("light.zig").theme },
    .{ .name = "tokyonight", .theme = @import("tokyonight.zig").theme },
    .{ .name = "catppuccin", .theme = @import("catppuccin.zig").theme },
    .{ .name = "dracula", .theme = @import("dracula.zig").theme },
    .{ .name = "nord", .theme = @import("nord.zig").theme },
    .{ .name = "github_dark", .theme = @import("github_dark.zig").theme },
    .{ .name = "onedark", .theme = @import("onedark.zig").theme },
    .{ .name = "solarized_dark", .theme = @import("solarized_dark.zig").theme },
    .{ .name = "solarized_light", .theme = @import("solarized_light.zig").theme },
    .{ .name = "monokai", .theme = @import("monokai.zig").theme },
    .{ .name = "monokai_nebula", .theme = @import("monokai_nebula.zig").theme },
    .{ .name = "github_light", .theme = @import("github_light.zig").theme },
    .{ .name = "ayu_dark", .theme = @import("ayu_dark.zig").theme },
    .{ .name = "ayu_light", .theme = @import("ayu_light.zig").theme },
    .{ .name = "flexoki_dark", .theme = @import("flexoki_dark.zig").theme },
    .{ .name = "flexoki_light", .theme = @import("flexoki_light.zig").theme },
    .{ .name = "rose_pine", .theme = @import("rose_pine.zig").theme },
    .{ .name = "rose_pine_dawn", .theme = @import("rose_pine_dawn.zig").theme },
    .{ .name = "everforest", .theme = @import("everforest.zig").theme },
    .{ .name = "kanagawa", .theme = @import("kanagawa.zig").theme },
};

/// Derived from `builtin_themes` — no separate maintenance.
pub const names_len = builtin_themes.len;
pub const names: [names_len][]const u8 = blk: {
    var result: [names_len][]const u8 = undefined;
    for (&result, 0..) |*r, i| {
        r.* = builtin_themes[i].name;
    }
    break :blk result;
};

/// Convenience aliases — single theme re-exports so consumers don't need
/// to re-run a name lookup for the most common fallback.
pub const hard = builtin_themes[0].theme;

pub fn byName(allocator: std.mem.Allocator, io: std.Io, environ_map: *std.process.Environ.Map, name: []const u8) ?Theme {
    // Check built-in themes first (O(1) amortized, zero allocation)
    inline for (builtin_themes) |entry| {
        if (std.mem.eql(u8, name, entry.name)) return entry.theme;
    }

    // Fall back to custom theme file lookup
    const custom_path = theme_loader.customThemePath(allocator, environ_map, name) catch null;
    if (custom_path) |path| {
        defer allocator.free(path);
        if (theme_loader.loadFromFile(allocator, io, path)) |theme| {
            return theme;
        } else |err| {
            if (err != error.ThemeReadError) {
                log.warn("failed to load custom theme '{s}' from {s}: {s}", .{ name, path, @errorName(err) });
            }
        }
    }
    return null;
}

test "byName returns correct themes" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    const hard_theme = byName(gpa, io, &env_map, "hard");
    try std.testing.expect(hard_theme != null);
    try std.testing.expect(!hard_theme.?.background.isDefault());
    try std.testing.expect(byName(gpa, io, &env_map, "tokyonight") != null);
    try std.testing.expect(byName(gpa, io, &env_map, "nord") != null);
    try std.testing.expect(byName(gpa, io, &env_map, "nonexistent") == null);
}

test "theme lookup" {
    const theme = builtin_themes[0].theme;
    try std.testing.expect(std.meta.eql(hard, theme));
    try std.testing.expect(std.meta.eql(tui.Color.hex(0x1b1b1b), theme.lookup("background").?));
    try std.testing.expect(std.meta.eql(tui.Color.hex(0x458588), theme.lookup("primary").?));
    try std.testing.expect(theme.lookup("nonexistent") == null);
}
