const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0xF9F5D7),
    .foreground = c(0x1b1b1b),
    .surface = c(0xEBDBB2),
    .surface_alt = c(0xF9F5D7),
    .primary = c(0x458588),
    .primary_bright = c(0x076678),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0xffffff),
    .success = c(0x5A7A0E),
    .success_bright = c(0x79740E),
    .danger = c(0xcc241d),
    .danger_bright = c(0x9D0006),
    .warning = c(0x9B6B00),
    .info = c(0x669a68),
    .info_bright = c(0x427B58),
    .accent = c(0xb16286),
    .accent_bright = c(0x8F3F71),
    .emphasis = c(0x1b1b1b),
    .muted = c(0x5A5048),
    .forge_github = c(0x1b1b1b),
    .forge_gitlab = c(0xC84A0E),
    .forge_codeberg = c(0xC84A0E),
};
