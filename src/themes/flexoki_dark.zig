const Theme = @import("../core/theme.zig").Theme;

pub const theme = Theme{
    .background = "#100F0F",
    .foreground = "#CECDC3",
    .surface = "#1C1B1A",
    .surface_alt = "#100F0F",
    .primary = "#4385BE",
    .primary_bright = "#3AA99F",
    .success = "#879A39",
    .success_bright = "#D0A215",
    .danger = "#D14D41",
    .danger_bright = "#DA702C",
    .warning = "#D0A215",
    .warning_bright = "#879A39",
    .info = "#4385BE",
    .info_bright = "#3AA99F",
    .accent = "#8B7EC8",
    .accent_bright = "#CE5D97",
    .emphasis = "#FFFCF0",
    .muted = "#6F6E69",
    .forge_github = "#CECDC3",
    .forge_gitlab = "#DA702C",
};
