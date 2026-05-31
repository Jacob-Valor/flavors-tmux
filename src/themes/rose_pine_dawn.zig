const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0xfaf4ed),
    .foreground = c(0x575279),
    .surface = c(0xfffaf3),
    .surface_alt = c(0xfaf4ed),
    .primary = c(0x286983),
    .primary_bright = c(0x56949f),
    .on_primary = c(0xffffff),
    .on_primary_bright = c(0x000000),
    .success = c(0x286983),
    .success_bright = c(0x56949f),
    .danger = c(0xb4637a),
    .danger_bright = c(0xd7827e),
    .warning = c(0xc18129),
    .info = c(0x907aa9),
    .info_bright = c(0xc87875),
    .accent = c(0x907aa9),
    .accent_bright = c(0x575279),
    .emphasis = c(0x575279),
    .muted = c(0x908c9d),
    .forge_github = c(0x575279),
    .forge_gitlab = c(0xC84A0E),
    .forge_codeberg = c(0xC84A0E),
};
