const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x1a1b26),
    .foreground = c(0xa9b1d6),
    .surface = c(0x24283b),
    .surface_alt = c(0x1a1b26),
    .primary = c(0x7aa2f7),
    .primary_bright = c(0xbb9af7),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0x9ece6a),
    .success_bright = c(0x73daca),
    .danger = c(0xf7768e),
    .danger_bright = c(0xdb4b4b),
    .warning = c(0xe0af68),
    .info = c(0x7dcfff),
    .info_bright = c(0xb4f9f8),
    .accent = c(0xbb9af7),
    .accent_bright = c(0xd5a8e3),
    .emphasis = c(0xc0caf5),
    .muted = c(0x565f89),
    .forge_github = c(0xa9b1d6),
    .forge_gitlab = c(0xfc6d26),
    .forge_codeberg = c(0xfc6d26),
};
