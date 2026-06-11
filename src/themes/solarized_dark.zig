const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x002b36),
    .foreground = c(0x839496),
    .surface = c(0x073642),
    .surface_alt = c(0x002b36),
    .primary = c(0x268bd2),
    .primary_bright = c(0x2aa198),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0x859900),
    .success_bright = c(0xb58900),
    .danger = c(0xdc322f),
    .danger_bright = c(0xcb4b16),
    .warning = c(0xb58900),
    .info = c(0x2aa198),
    .info_bright = c(0x268bd2),
    .accent = c(0x6c71c4),
    .accent_bright = c(0xd33682),
    .emphasis = c(0x93a1a1),
    .muted = c(0x586e75),
    .forge_github = c(0x839496),
    .forge_gitlab = c(0xfc6d26),
    .forge_codeberg = c(0xfc6d26),
};
