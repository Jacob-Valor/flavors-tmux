const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0xFFFCF0),
    .foreground = c(0x100F0F),
    .surface = c(0xF2F0E5),
    .surface_alt = c(0xFFFCF0),
    .primary = c(0x205EA6),
    .primary_bright = c(0x4385BE),
    .on_primary = c(0xffffff),
    .on_primary_bright = c(0x000000),
    .success = c(0x66800B),
    .success_bright = c(0x879A39),
    .danger = c(0xAF3029),
    .danger_bright = c(0xD14D41),
    .warning = c(0xAD8301),
    .info = c(0x205EA6),
    .info_bright = c(0x4385BE),
    .accent = c(0x5E409D),
    .accent_bright = c(0x8B7EC8),
    .emphasis = c(0x100F0F),
    .muted = c(0x878580),
    .forge_github = c(0x100F0F),
    .forge_gitlab = c(0xBC5215),
    .forge_codeberg = c(0xBC5215),
};
