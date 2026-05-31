const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x0D1017),
    .foreground = c(0xBFBDB6),
    .surface = c(0x141821),
    .surface_alt = c(0x0D1017),
    .primary = c(0xE6B450),
    .primary_bright = c(0xFFB454),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0x70BF56),
    .success_bright = c(0x7EE787),
    .danger = c(0xF26D78),
    .danger_bright = c(0xFF7B86),
    .warning = c(0xE6B450),
    .info = c(0x59C2FF),
    .info_bright = c(0x7FD1FF),
    .accent = c(0xD2A6FF),
    .accent_bright = c(0xE5C4FF),
    .emphasis = c(0xE6E1D7),
    .muted = c(0xACB6BF),
    .forge_github = c(0xBFBDB6),
    .forge_gitlab = c(0xFC6D26),
    .forge_codeberg = c(0xFC6D26),
};
