const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x2d353b),
    .foreground = c(0xd3c6aa),
    .surface = c(0x343f44),
    .surface_alt = c(0x2d353b),
    .primary = c(0x7fbbb3),
    .primary_bright = c(0x83c092),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0xa7c080),
    .success_bright = c(0x83c092),
    .danger = c(0xe67e80),
    .danger_bright = c(0xe69875),
    .warning = c(0xdbbc7f),
    .info = c(0x7fbbb3),
    .info_bright = c(0x83c092),
    .accent = c(0xd699b6),
    .accent_bright = c(0xd3c6aa),
    .emphasis = c(0xd3c6aa),
    .muted = c(0x7a8478),
    .forge_github = c(0xd3c6aa),
    .forge_gitlab = c(0xe69875),
    .forge_codeberg = c(0xe69875),
};
