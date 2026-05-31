const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x191724),
    .foreground = c(0xe0def4),
    .surface = c(0x1f1d2e),
    .surface_alt = c(0x191724),
    .primary = c(0x31748f),
    .primary_bright = c(0x9ccfd8),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0x31748f),
    .success_bright = c(0x9ccfd8),
    .danger = c(0xeb6f92),
    .danger_bright = c(0xebbcba),
    .warning = c(0xf6c177),
    .info = c(0xc4a7e7),
    .info_bright = c(0xebbcba),
    .accent = c(0xc4a7e7),
    .accent_bright = c(0xe0def4),
    .emphasis = c(0xe0def4),
    .muted = c(0x6e6a86),
    .forge_github = c(0xe0def4),
    .forge_gitlab = c(0xfc6d26),
    .forge_codeberg = c(0xfc6d26),
};
