const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x2e3440),
    .foreground = c(0xd8dee9),
    .surface = c(0x3b4252),
    .surface_alt = c(0x2e3440),
    .primary = c(0x88c0d0),
    .primary_bright = c(0x8fbcbb),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0xa3be8c),
    .success_bright = c(0xa3be8c),
    .danger = c(0xbf616a),
    .danger_bright = c(0xd08770),
    .warning = c(0xebcb8b),
    .info = c(0x81a1c1),
    .info_bright = c(0x5e81ac),
    .accent = c(0xb48ead),
    .accent_bright = c(0xc895bf),
    .emphasis = c(0xeceff4),
    .muted = c(0x4c566a),
    .forge_github = c(0xd8dee9),
    .forge_gitlab = c(0xfc6d26),
    .forge_codeberg = c(0xfc6d26),
};
