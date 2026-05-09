const std = @import("std");
const Theme = @import("../core/theme.zig").Theme;

const hard_mod = @import("hard.zig");
const medium_mod = @import("medium.zig");
const soft_mod = @import("soft.zig");
const light_mod = @import("light.zig");
const tokyonight_mod = @import("tokyonight.zig");
const catppuccin_mod = @import("catppuccin.zig");
const dracula_mod = @import("dracula.zig");
const nord_mod = @import("nord.zig");

pub const hard = hard_mod.theme;
pub const medium = medium_mod.theme;
pub const soft = soft_mod.theme;
pub const light = light_mod.theme;
pub const tokyonight = tokyonight_mod.theme;
pub const catppuccin = catppuccin_mod.theme;
pub const dracula = dracula_mod.theme;
pub const nord = nord_mod.theme;

pub fn byName(name: []const u8) ?Theme {
    if (std.mem.eql(u8, name, "hard")) return hard;
    if (std.mem.eql(u8, name, "medium")) return medium;
    if (std.mem.eql(u8, name, "soft")) return soft;
    if (std.mem.eql(u8, name, "light")) return light;
    if (std.mem.eql(u8, name, "tokyonight")) return tokyonight;
    if (std.mem.eql(u8, name, "catppuccin")) return catppuccin;
    if (std.mem.eql(u8, name, "dracula")) return dracula;
    if (std.mem.eql(u8, name, "nord")) return nord;
    return null;
}

pub const names = [_][]const u8{
    "hard",       "medium",    "soft",     "light",
    "tokyonight", "catppuccin", "dracula", "nord",
};

test "byName returns correct themes" {
    try std.testing.expect(byName("hard").?.background[0] == '#');
    try std.testing.expect(byName("tokyonight") != null);
    try std.testing.expect(byName("nord") != null);
    try std.testing.expect(byName("nonexistent") == null);
}

test "theme lookup" {
    const theme = hard;
    try std.testing.expectEqualStrings("#1b1b1b", theme.lookup("background").?);
    try std.testing.expectEqualStrings("#458588", theme.lookup("primary").?);
    try std.testing.expect(theme.lookup("nonexistent") == null);
}
