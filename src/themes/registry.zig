const std = @import("std");
const Theme = @import("../core/theme.zig").Theme;
const theme_loader = @import("../core/theme_loader.zig");

const log = std.log.scoped(.themes);

const hard_mod = @import("hard.zig");
const medium_mod = @import("medium.zig");
const soft_mod = @import("soft.zig");
const light_mod = @import("light.zig");
const tokyonight_mod = @import("tokyonight.zig");
const catppuccin_mod = @import("catppuccin.zig");
const dracula_mod = @import("dracula.zig");
const nord_mod = @import("nord.zig");
const github_dark_mod = @import("github_dark.zig");
const onedark_mod = @import("onedark.zig");
const solarized_dark_mod = @import("solarized_dark.zig");
const solarized_light_mod = @import("solarized_light.zig");
const monokai_mod = @import("monokai.zig");
const monokai_nebula_mod = @import("monokai_nebula.zig");
const github_light_mod = @import("github_light.zig");
const ayu_dark_mod = @import("ayu_dark.zig");
const ayu_light_mod = @import("ayu_light.zig");
const flexoki_dark_mod = @import("flexoki_dark.zig");
const flexoki_light_mod = @import("flexoki_light.zig");

pub const hard = hard_mod.theme;
pub const medium = medium_mod.theme;
pub const soft = soft_mod.theme;
pub const light = light_mod.theme;
pub const tokyonight = tokyonight_mod.theme;
pub const catppuccin = catppuccin_mod.theme;
pub const dracula = dracula_mod.theme;
pub const nord = nord_mod.theme;
pub const github_dark = github_dark_mod.theme;
pub const onedark = onedark_mod.theme;
pub const solarized_dark = solarized_dark_mod.theme;
pub const solarized_light = solarized_light_mod.theme;
pub const monokai = monokai_mod.theme;
pub const monokai_nebula = monokai_nebula_mod.theme;
pub const github_light = github_light_mod.theme;
pub const ayu_dark = ayu_dark_mod.theme;
pub const ayu_light = ayu_light_mod.theme;
pub const flexoki_dark = flexoki_dark_mod.theme;
pub const flexoki_light = flexoki_light_mod.theme;

pub fn byName(allocator: std.mem.Allocator, io: std.Io, environ_map: *std.process.Environ.Map, name: []const u8) ?Theme {
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

    inline for (comptime .{
        .{ "hard", hard },
        .{ "medium", medium },
        .{ "soft", soft },
        .{ "light", light },
        .{ "tokyonight", tokyonight },
        .{ "catppuccin", catppuccin },
        .{ "dracula", dracula },
        .{ "nord", nord },
        .{ "github_dark", github_dark },
        .{ "onedark", onedark },
        .{ "solarized_dark", solarized_dark },
        .{ "solarized_light", solarized_light },
        .{ "monokai", monokai },
        .{ "monokai_nebula", monokai_nebula },
        .{ "github_light", github_light },
        .{ "ayu_dark", ayu_dark },
        .{ "ayu_light", ayu_light },
        .{ "flexoki_dark", flexoki_dark },
        .{ "flexoki_light", flexoki_light },
    }) |entry| {
        if (std.mem.eql(u8, name, entry.@"0")) return entry.@"1";
    }
    return null;
}

pub const names = [_][]const u8{
    "hard",        "medium",         "soft",           "light",
    "tokyonight",  "catppuccin",     "dracula",        "nord",
    "github_dark", "onedark",        "solarized_dark", "solarized_light",
    "monokai",     "monokai_nebula", "github_light",   "ayu_dark",
    "ayu_light",   "flexoki_dark",   "flexoki_light",
};

test "byName returns correct themes" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    const hard_theme = byName(gpa, io, &env_map, "hard");
    try std.testing.expect(hard_theme != null);
    try std.testing.expect(hard_theme.?.background[0] == '#');
    try std.testing.expect(byName(gpa, io, &env_map, "tokyonight") != null);
    try std.testing.expect(byName(gpa, io, &env_map, "nord") != null);
    try std.testing.expect(byName(gpa, io, &env_map, "nonexistent") == null);
}

test "theme lookup" {
    const theme = hard;
    try std.testing.expectEqualStrings("#1b1b1b", theme.lookup("background").?);
    try std.testing.expectEqualStrings("#458588", theme.lookup("primary").?);
    try std.testing.expect(theme.lookup("nonexistent") == null);
}
