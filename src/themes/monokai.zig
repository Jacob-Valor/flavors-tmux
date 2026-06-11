const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x272822),
    .foreground = c(0xf8f8f2),
    .surface = c(0x3e3d32),
    .surface_alt = c(0x272822),
    .primary = c(0x66d9ef),
    .primary_bright = c(0xa1efe4),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0xa6e22e),
    .success_bright = c(0xc1f161),
    .danger = c(0xf92672),
    .danger_bright = c(0xfc5c94),
    .warning = c(0xfd971f),
    .info = c(0x66d9ef),
    .info_bright = c(0xa1efe4),
    .accent = c(0xae81ff),
    .accent_bright = c(0xc2a1ff),
    .emphasis = c(0xf8f8f0),
    .muted = c(0x75715e),
    .forge_github = c(0xf8f8f2),
    .forge_gitlab = c(0xfc6d26),
    .forge_codeberg = c(0xfc6d26),
};
