const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x282a36),
    .foreground = c(0xf8f8f2),
    .surface = c(0x44475a),
    .surface_alt = c(0x282a36),
    .primary = c(0x8be9fd),
    .primary_bright = c(0x9aedfe),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0x50fa7b),
    .success_bright = c(0x69ff94),
    .danger = c(0xff5555),
    .danger_bright = c(0xff6e6e),
    .warning = c(0xf1fa8c),
    .info = c(0xbd93f9),
    .info_bright = c(0xd6acff),
    .accent = c(0xff79c6),
    .accent_bright = c(0xff92df),
    .emphasis = c(0xf8f8f2),
    .muted = c(0x6272a4),
    .forge_github = c(0xf8f8f2),
    .forge_gitlab = c(0xfc6d26),
    .forge_codeberg = c(0xfc6d26),
};
