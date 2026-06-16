const std = @import("std");
const tui = @import("tui");
const Theme = @import("../core/theme.zig").Theme;
const theme_loader = @import("../core/theme_loader.zig");

const log = std.log.scoped(.themes);

const hard = @import("hard.zig").theme;
const medium = @import("medium.zig").theme;
const soft = @import("soft.zig").theme;
const light = @import("light.zig").theme;
const tokyonight = @import("tokyonight.zig").theme;
const catppuccin = @import("catppuccin.zig").theme;
const dracula = @import("dracula.zig").theme;
const nord = @import("nord.zig").theme;
const github_dark = @import("github_dark.zig").theme;
const onedark = @import("onedark.zig").theme;
const solarized_dark = @import("solarized_dark.zig").theme;
const solarized_light = @import("solarized_light.zig").theme;
const monokai = @import("monokai.zig").theme;
const monokai_nebula = @import("monokai_nebula.zig").theme;
const github_light = @import("github_light.zig").theme;
const ayu_dark = @import("ayu_dark.zig").theme;
const ayu_light = @import("ayu_light.zig").theme;
const flexoki_dark = @import("flexoki_dark.zig").theme;
const flexoki_light = @import("flexoki_light.zig").theme;
const rose_pine = @import("rose_pine.zig").theme;
const rose_pine_dawn = @import("rose_pine_dawn.zig").theme;
const everforest = @import("everforest.zig").theme;
const kanagawa = @import("kanagawa.zig").theme;

/// Single source of truth: every theme appears here once.
/// `names`, `byName()`, and any future theme iteration derive from this array.
const builtin_themes = comptime [_]struct { name: []const u8, theme: Theme }{
    .{ .name = "hard", .theme = hard },
    .{ .name = "medium", .theme = medium },
    .{ .name = "soft", .theme = soft },
    .{ .name = "light", .theme = light },
    .{ .name = "tokyonight", .theme = tokyonight },
    .{ .name = "catppuccin", .theme = catppuccin },
    .{ .name = "dracula", .theme = dracula },
    .{ .name = "nord", .theme = nord },
    .{ .name = "github_dark", .theme = github_dark },
    .{ .name = "onedark", .theme = onedark },
    .{ .name = "solarized_dark", .theme = solarized_dark },
    .{ .name = "solarized_light", .theme = solarized_light },
    .{ .name = "monokai", .theme = monokai },
    .{ .name = "monokai_nebula", .theme = monokai_nebula },
    .{ .name = "github_light", .theme = github_light },
    .{ .name = "ayu_dark", .theme = ayu_dark },
    .{ .name = "ayu_light", .theme = ayu_light },
    .{ .name = "flexoki_dark", .theme = flexoki_dark },
    .{ .name = "flexoki_light", .theme = flexoki_light },
    .{ .name = "rose_pine", .theme = rose_pine },
    .{ .name = "rose_pine_dawn", .theme = rose_pine_dawn },
    .{ .name = "everforest", .theme = everforest },
    .{ .name = "kanagawa", .theme = kanagawa },
};

/// Derived from `builtin_themes` — no separate maintenance.
pub const names: []const []const u8 = comptime blk: {
    var result: [builtin_themes.len][]const u8 = undefined;
    for (&result, 0..) |*r, i| {
        r.* = builtin_themes[i].name;
    }
    break :blk &result;
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
