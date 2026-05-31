const tui = @import("tui");
const c = tui.Color.hex;
const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = c(0x1e1e2e),
    .foreground = c(0xcdd6f4),
    .surface = c(0x313244),
    .surface_alt = c(0x1e1e2e),
    .primary = c(0x89b4fa),
    .primary_bright = c(0xb4befe),
    .on_primary = c(0x000000),
    .on_primary_bright = c(0x000000),
    .success = c(0xa6e3a1),
    .success_bright = c(0x94e2d5),
    .danger = c(0xf38ba8),
    .danger_bright = c(0xeba0ac),
    .warning = c(0xfab387),
    .info = c(0x89dceb),
    .info_bright = c(0x74c7ec),
    .accent = c(0xcba6f7),
    .accent_bright = c(0xf5c2e7),
    .emphasis = c(0xcdd6f4),
    .muted = c(0x6c7086),
    .forge_github = c(0xcdd6f4),
    .forge_gitlab = c(0xfc6d26),
    .forge_codeberg = c(0xfc6d26),
};
