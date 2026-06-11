const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x0d1117),
    .foreground = c(0xc9d1d9),
    .surface = c(0x161b22),
    .surface_alt = c(0x0d1117),
    .primary = c(0x58a6ff),
    .primary_bright = c(0x79c0ff),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0x238636),
    .success_bright = c(0x3fb950),
    .danger = c(0xda3633),
    .danger_bright = c(0xf85149),
    .warning = c(0xd29922),
    .info = c(0x58a6ff),
    .info_bright = c(0x79c0ff),
    .accent = c(0xa371f7),
    .accent_bright = c(0xbc8cff),
    .emphasis = c(0xf0f6fc),
    .muted = c(0x8b949e),
    .forge_github = c(0xf0f6fc),
    .forge_gitlab = c(0xfc6d26),
    .forge_codeberg = c(0xfc6d26),
};
