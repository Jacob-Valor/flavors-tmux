const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x282c34),
    .foreground = c(0xabb2bf),
    .surface = c(0x3e4451),
    .surface_alt = c(0x282c34),
    .primary = c(0x61afef),
    .primary_bright = c(0x528bcc),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0x98c379),
    .success_bright = c(0x7cb96b),
    .danger = c(0xe06c75),
    .danger_bright = c(0xc8555d),
    .warning = c(0xe5c07b),
    .info = c(0x56b6c2),
    .info_bright = c(0x4a9da8),
    .accent = c(0xc678dd),
    .accent_bright = c(0xb068c8),
    .emphasis = c(0xabb2bf),
    .muted = c(0x5c6370),
    .forge_github = c(0xabb2bf),
    .forge_gitlab = c(0xfc6d26),
    .forge_codeberg = c(0xfc6d26),
};
