const std = @import("std");

pub const Theme = struct {
    background: []const u8,
    foreground: []const u8,
    surface: []const u8,
    surface_alt: []const u8,
    primary: []const u8,
    primary_bright: []const u8,
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

    pub fn lookup(self: Theme, key: []const u8) ?[]const u8 {
        if (std.mem.eql(u8, key, "background")) return self.background;
        if (std.mem.eql(u8, key, "foreground")) return self.foreground;
        if (std.mem.eql(u8, key, "surface")) return self.surface;
        if (std.mem.eql(u8, key, "surface_alt")) return self.surface_alt;
        if (std.mem.eql(u8, key, "primary")) return self.primary;
        if (std.mem.eql(u8, key, "primary_bright")) return self.primary_bright;
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
        return null;
    }
};

pub const hard = Theme{
    .background = "#1b1b1b",
    .foreground = "#fbf1c7",
    .surface = "#282828",
    .surface_alt = "#1b1b1b",
    .primary = "#458588",
    .primary_bright = "#83a598",
    .success = "#98971a",
    .success_bright = "#b8bb26",
    .danger = "#cc241d",
    .danger_bright = "#fb4934",
    .warning = "#d79921",
    .warning_bright = "#fabd2f",
    .info = "#689d6a",
    .info_bright = "#8ec07c",
    .accent = "#b16286",
    .accent_bright = "#d3869b",
    .emphasis = "#fbf1c7",
    .muted = "#a89984",
    .forge_github = "#fbf1c7",
    .forge_gitlab = "#fc6d26",
};

pub const medium = Theme{
    .background = "#282828",
    .foreground = "#fbf1c7",
    .surface = "#32302F",
    .surface_alt = "#282828",
    .primary = "#458588",
    .primary_bright = "#83a598",
    .success = "#98971a",
    .success_bright = "#b8bb26",
    .danger = "#cc241d",
    .danger_bright = "#fb4934",
    .warning = "#d79921",
    .warning_bright = "#fabd2f",
    .info = "#689d6a",
    .info_bright = "#8ec07c",
    .accent = "#b16286",
    .accent_bright = "#d3869b",
    .emphasis = "#fbf1c7",
    .muted = "#a89984",
    .forge_github = "#fbf1c7",
    .forge_gitlab = "#fc6d26",
};

pub const soft = Theme{
    .background = "#32302F",
    .foreground = "#fbf1c7",
    .surface = "#3C3836",
    .surface_alt = "#32302F",
    .primary = "#458588",
    .primary_bright = "#83a598",
    .success = "#98971a",
    .success_bright = "#b8bb26",
    .danger = "#cc241d",
    .danger_bright = "#fb4934",
    .warning = "#d79921",
    .warning_bright = "#fabd2f",
    .info = "#689d6a",
    .info_bright = "#8ec07c",
    .accent = "#b16286",
    .accent_bright = "#d3869b",
    .emphasis = "#fbf1c7",
    .muted = "#a89984",
    .forge_github = "#fbf1c7",
    .forge_gitlab = "#fc6d26",
};

pub const light = Theme{
    .background = "#F9F5D7",
    .foreground = "#1b1b1b",
    .surface = "#EBDBB2",
    .surface_alt = "#F9F5D7",
    .primary = "#458588",
    .primary_bright = "#076678",
    .success = "#98971a",
    .success_bright = "#79740E",
    .danger = "#cc241d",
    .danger_bright = "#9D0006",
    .warning = "#d79921",
    .warning_bright = "#B57614",
    .info = "#689d6a",
    .info_bright = "#427B58",
    .accent = "#b16286",
    .accent_bright = "#8F3F71",
    .emphasis = "#1b1b1b",
    .muted = "#7c6f64",
    .forge_github = "#1b1b1b",
    .forge_gitlab = "#fc6d26",
};

pub const tokyonight = Theme{
    .background = "#1a1b26",
    .foreground = "#a9b1d6",
    .surface = "#24283b",
    .surface_alt = "#1a1b26",
    .primary = "#7aa2f7",
    .primary_bright = "#bb9af7",
    .success = "#9ece6a",
    .success_bright = "#73daca",
    .danger = "#f7768e",
    .danger_bright = "#db4b4b",
    .warning = "#e0af68",
    .warning_bright = "#ff9e64",
    .info = "#7dcfff",
    .info_bright = "#b4f9f8",
    .accent = "#bb9af7",
    .accent_bright = "#d5a8e3",
    .emphasis = "#c0caf5",
    .muted = "#565f89",
    .forge_github = "#a9b1d6",
    .forge_gitlab = "#fc6d26",
};

pub const catppuccin = Theme{
    .background = "#1e1e2e",
    .foreground = "#cdd6f4",
    .surface = "#313244",
    .surface_alt = "#1e1e2e",
    .primary = "#89b4fa",
    .primary_bright = "#b4befe",
    .success = "#a6e3a1",
    .success_bright = "#94e2d5",
    .danger = "#f38ba8",
    .danger_bright = "#eba0ac",
    .warning = "#fab387",
    .warning_bright = "#f9e2af",
    .info = "#89dceb",
    .info_bright = "#74c7ec",
    .accent = "#cba6f7",
    .accent_bright = "#f5c2e7",
    .emphasis = "#cdd6f4",
    .muted = "#6c7086",
    .forge_github = "#cdd6f4",
    .forge_gitlab = "#fc6d26",
};

pub const dracula = Theme{
    .background = "#282a36",
    .foreground = "#f8f8f2",
    .surface = "#44475a",
    .surface_alt = "#282a36",
    .primary = "#8be9fd",
    .primary_bright = "#9aedfe",
    .success = "#50fa7b",
    .success_bright = "#69ff94",
    .danger = "#ff5555",
    .danger_bright = "#ff6e6e",
    .warning = "#f1fa8c",
    .warning_bright = "#ffffa5",
    .info = "#bd93f9",
    .info_bright = "#d6acff",
    .accent = "#ff79c6",
    .accent_bright = "#ff92df",
    .emphasis = "#f8f8f2",
    .muted = "#6272a4",
    .forge_github = "#f8f8f2",
    .forge_gitlab = "#fc6d26",
};

pub const nord = Theme{
    .background = "#2e3440",
    .foreground = "#d8dee9",
    .surface = "#3b4252",
    .surface_alt = "#2e3440",
    .primary = "#88c0d0",
    .primary_bright = "#8fbcbb",
    .success = "#a3be8c",
    .success_bright = "#bf616a",
    .danger = "#bf616a",
    .danger_bright = "#d08770",
    .warning = "#ebcb8b",
    .warning_bright = "#e5e9f0",
    .info = "#81a1c1",
    .info_bright = "#5e81ac",
    .accent = "#b48ead",
    .accent_bright = "#c895bf",
    .emphasis = "#eceff4",
    .muted = "#4c566a",
    .forge_github = "#d8dee9",
    .forge_gitlab = "#fc6d26",
};

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
    "hard", "medium", "soft", "light",
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
