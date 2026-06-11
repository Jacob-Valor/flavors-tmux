const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0xF8F9FA),
    .foreground = c(0x5C6166),
    .surface = c(0xFFFFFF),
    .surface_alt = c(0xF8F9FA),
    .primary = c(0x8A5500),
    .primary_bright = c(0xEBA400),
    .on_primary = c(0xffffff),
    .on_primary_bright = c(0x000000),
    .success = c(0x3B7A1A),
    .success_bright = c(0x2D7A1A),
    .danger = c(0xB82A3A),
    .danger_bright = c(0xC84454),
    .warning = c(0x8A5500),
    .info = c(0x2A6B9E),
    .info_bright = c(0x2A6B9E),
    .accent = c(0xA37ACC),
    .accent_bright = c(0x7850A0),
    .emphasis = c(0x24292E),
    .muted = c(0x6A6F74),
    .forge_github = c(0x5C6166),
    .forge_gitlab = c(0xB83E00),
    .forge_codeberg = c(0xB83E00),
};
