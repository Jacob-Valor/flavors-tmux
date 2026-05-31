const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x101010),
    .foreground = c(0xf8f8f2),
    .surface = c(0x1a1a1a),
    .surface_alt = c(0x101010),
    .primary = c(0x66d9ff),
    .primary_bright = c(0x8ee5ff),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0xa6ff2e),
    .success_bright = c(0xc6ff6e),
    .danger = c(0xf92672),
    .danger_bright = c(0xfc5c94),
    .warning = c(0xff971f),
    .info = c(0x66d9ff),
    .info_bright = c(0x8ee5ff),
    .accent = c(0xae81ff),
    .accent_bright = c(0xc2a1ff),
    .emphasis = c(0xf8f8f2),
    .muted = c(0x75715e),
    .forge_github = c(0xf8f8f2),
    .forge_gitlab = c(0xfc6d26),
    .forge_codeberg = c(0xfc6d26),
};
