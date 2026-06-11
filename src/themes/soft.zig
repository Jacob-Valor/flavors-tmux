const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x32302F),
    .foreground = c(0xfbf1c7),
    .surface = c(0x3C3836),
    .surface_alt = c(0x32302F),
    .primary = c(0x458588),
    .primary_bright = c(0x83a598),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0x98971a),
    .success_bright = c(0xb8bb26),
    .danger = c(0xcc241d),
    .danger_bright = c(0xfb4934),
    .warning = c(0xd79921),
    .info = c(0x689d6a),
    .info_bright = c(0x8ec07c),
    .accent = c(0xb16286),
    .accent_bright = c(0xd3869b),
    .emphasis = c(0xfbf1c7),
    .muted = c(0xa89984),
    .forge_github = c(0xfbf1c7),
    .forge_gitlab = c(0xfc6d26),
    .forge_codeberg = c(0xfc6d26),
};
