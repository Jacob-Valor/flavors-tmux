const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0xfdf6e3),
    .foreground = c(0x60757c),
    .surface = c(0xeee8d5),
    .surface_alt = c(0xfdf6e3),
    .primary = c(0x268bd2),
    .primary_bright = c(0x2aa198),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0x5A6B00),
    .success_bright = c(0x7A5A00),
    .danger = c(0xdc322f),
    .danger_bright = c(0xcb4b16),
    .warning = c(0x7A5A00),
    .info = c(0x1E7A72),
    .info_bright = c(0x268bd2),
    .accent = c(0x6c71c4),
    .accent_bright = c(0xd33682),
    .emphasis = c(0x586e75),
    .muted = c(0x5A6868),
    .forge_github = c(0x657b83),
    .forge_gitlab = c(0xB83E00),
    .forge_codeberg = c(0xB83E00),
};
