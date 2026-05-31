const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x100F0F),
    .foreground = c(0xCECDC3),
    .surface = c(0x1C1B1A),
    .surface_alt = c(0x100F0F),
    .primary = c(0x4385BE),
    .primary_bright = c(0x3AA99F),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0x879A39),
    .success_bright = c(0xD0A215),
    .danger = c(0xD14D41),
    .danger_bright = c(0xDA702C),
    .warning = c(0xD0A215),
    .info = c(0x4385BE),
    .info_bright = c(0x3AA99F),
    .accent = c(0x8B7EC8),
    .accent_bright = c(0xCE5D97),
    .emphasis = c(0xFFFCF0),
    .muted = c(0x6F6E69),
    .forge_github = c(0xCECDC3),
    .forge_gitlab = c(0xDA702C),
    .forge_codeberg = c(0xDA702C),
};
