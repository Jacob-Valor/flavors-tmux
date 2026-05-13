const std = @import("std");
const Theme = @import("../core/theme.zig").Theme;
const theme_loader = @import("../core/theme_loader.zig");

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
const rose_pine_mod = @import("rose_pine.zig");
const rose_pine_moon_mod = @import("rose_pine_moon.zig");
const rose_pine_dawn_mod = @import("rose_pine_dawn.zig");
const kanagawa_mod = @import("kanagawa.zig");
const kanagawa_dragon_mod = @import("kanagawa_dragon.zig");
const kanagawa_lotus_mod = @import("kanagawa_lotus.zig");
const everforest_dark_mod = @import("everforest_dark.zig");
const everforest_light_mod = @import("everforest_light.zig");

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
pub const rose_pine = rose_pine_mod.theme;
pub const rose_pine_moon = rose_pine_moon_mod.theme;
pub const rose_pine_dawn = rose_pine_dawn_mod.theme;
pub const kanagawa = kanagawa_mod.theme;
pub const kanagawa_dragon = kanagawa_dragon_mod.theme;
pub const kanagawa_lotus = kanagawa_lotus_mod.theme;
pub const everforest_dark = everforest_dark_mod.theme;
pub const everforest_light = everforest_light_mod.theme;

pub fn byName(allocator: std.mem.Allocator, io: std.Io, environ_map: *std.process.Environ.Map, name: []const u8) ?Theme {
    const custom_path = theme_loader.customThemePath(allocator, environ_map, name) catch null;
    if (custom_path) |path| {
        defer allocator.free(path);
        if (theme_loader.loadFromFile(allocator, io, path)) |theme| {
            return theme;
        } else |_| {}
    }

    if (std.mem.eql(u8, name, "hard")) return hard;
    if (std.mem.eql(u8, name, "medium")) return medium;
    if (std.mem.eql(u8, name, "soft")) return soft;
    if (std.mem.eql(u8, name, "light")) return light;
    if (std.mem.eql(u8, name, "tokyonight")) return tokyonight;
    if (std.mem.eql(u8, name, "catppuccin")) return catppuccin;
    if (std.mem.eql(u8, name, "dracula")) return dracula;
    if (std.mem.eql(u8, name, "nord")) return nord;
    if (std.mem.eql(u8, name, "github_dark")) return github_dark;
    if (std.mem.eql(u8, name, "onedark")) return onedark;
    if (std.mem.eql(u8, name, "solarized_dark")) return solarized_dark;
    if (std.mem.eql(u8, name, "solarized_light")) return solarized_light;
    if (std.mem.eql(u8, name, "monokai")) return monokai;
    if (std.mem.eql(u8, name, "monokai_nebula")) return monokai_nebula;
    if (std.mem.eql(u8, name, "github_light")) return github_light;
    if (std.mem.eql(u8, name, "ayu_dark")) return ayu_dark;
    if (std.mem.eql(u8, name, "ayu_light")) return ayu_light;
    if (std.mem.eql(u8, name, "flexoki_dark")) return flexoki_dark;
    if (std.mem.eql(u8, name, "flexoki_light")) return flexoki_light;
    if (std.mem.eql(u8, name, "rose_pine")) return rose_pine;
    if (std.mem.eql(u8, name, "rose_pine_moon")) return rose_pine_moon;
    if (std.mem.eql(u8, name, "rose_pine_dawn")) return rose_pine_dawn;
    if (std.mem.eql(u8, name, "kanagawa")) return kanagawa;
    if (std.mem.eql(u8, name, "kanagawa_dragon")) return kanagawa_dragon;
    if (std.mem.eql(u8, name, "kanagawa_lotus")) return kanagawa_lotus;
    if (std.mem.eql(u8, name, "everforest_dark")) return everforest_dark;
    if (std.mem.eql(u8, name, "everforest_light")) return everforest_light;
    return null;
}

pub const names = [_][]const u8{
    "hard",              "medium",         "soft",           "light",
    "tokyonight",        "catppuccin",     "dracula",        "nord",
    "github_dark",       "onedark",        "solarized_dark", "solarized_light",
    "monokai",           "monokai_nebula", "github_light",   "ayu_dark",
    "ayu_light",         "flexoki_dark",   "flexoki_light",  "rose_pine",
    "rose_pine_moon",    "rose_pine_dawn", "kanagawa",       "kanagawa_dragon",
    "kanagawa_lotus",    "everforest_dark", "everforest_light",
};

test "byName returns correct themes" {
    try std.testing.expect(byName("hard").?.background[0] == '#');
    try std.testing.expect(byName("tokyonight") != null);
    try std.testing.expect(byName("nord") != null);
    try std.testing.expect(byName("rose_pine") != null);
    try std.testing.expect(byName("rose_pine_moon") != null);
    try std.testing.expect(byName("rose_pine_dawn") != null);
    try std.testing.expect(byName("kanagawa") != null);
    try std.testing.expect(byName("kanagawa_dragon") != null);
    try std.testing.expect(byName("kanagawa_lotus") != null);
    try std.testing.expect(byName("everforest_dark") != null);
    try std.testing.expect(byName("everforest_light") != null);
    try std.testing.expect(byName("nonexistent") == null);
}

test "theme lookup" {
    const theme = hard;
    try std.testing.expectEqualStrings("#1b1b1b", theme.lookup("background").?);
    try std.testing.expectEqualStrings("#458588", theme.lookup("primary").?);
    try std.testing.expect(theme.lookup("nonexistent") == null);
}
