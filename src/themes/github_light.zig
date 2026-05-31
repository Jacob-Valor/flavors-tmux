const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0xffffff),
    .foreground = c(0x1f2328),
    .surface = c(0xf6f8fa),
    .surface_alt = c(0xffffff),
    .primary = c(0x0969da),
    .primary_bright = c(0x218bff),
    .on_primary = c(0xffffff),
    .on_primary_bright = c(0x000000),
    .success = c(0x1a7f37),
    .success_bright = c(0x2da44e),
    .danger = c(0xcf222e),
    .danger_bright = c(0xfa4549),
    .warning = c(0x9a6700),
    .info = c(0x0969da),
    .info_bright = c(0x218bff),
    .accent = c(0x8250df),
    .accent_bright = c(0xa475f9),
    .emphasis = c(0x1f2328),
    .muted = c(0x656d76),
    .forge_github = c(0x1f2328),
    .forge_gitlab = c(0xC84A0E),
    .forge_codeberg = c(0xC84A0E),
};
