const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x1F1F28),
    .foreground = c(0xDCD7BA),
    .surface = c(0x2A2A37),
    .surface_alt = c(0x1F1F28),
    .primary = c(0x7E9CD8),
    .primary_bright = c(0x7FB4CA),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0x76946A),
    .success_bright = c(0x98BB6C),
    .danger = c(0xC34043),
    .danger_bright = c(0xE46876),
    .warning = c(0xDCA561),
    .info = c(0x7E9CD8),
    .info_bright = c(0x7FB4CA),
    .accent = c(0x957FB8),
    .accent_bright = c(0xD27E99),
    .emphasis = c(0xDCD7BA),
    .muted = c(0x727169),
    .forge_github = c(0xDCD7BA),
    .forge_gitlab = c(0xE46876),
    .forge_codeberg = c(0xE46876),
};
