const std = @import("std");
const themes = @import("../themes/registry.zig");

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    theme_name: []const u8,
    transparent: bool,
    environ_map: *std.process.Environ.Map,
    writer: *std.Io.Writer,
) !void {
    const theme = (themes.byName(allocator, io, environ_map, theme_name) orelse themes.hard).withTransparentBackground(transparent);

    const is_ssh = environ_map.get("SSH_CONNECTION") != null or environ_map.get("SSH_CLIENT") != null;

    var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const hostname = std.posix.gethostname(&buf) catch "unknown";

    const reset = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},nobold,noitalics,nounderscore,nodim]", .{
        theme.foreground,
        theme.background,
    });
    defer allocator.free(reset);

    if (is_ssh) {
        try writer.print("{s}#[fg={s},bg={s},bold]▒ 󰣀 {s}", .{
            reset,
            theme.warning,
            theme.background,
            hostname,
        });
    } else {
        try writer.print("{s}#[fg={s},bg={s},bold]▒ 󰌽 {s}", .{
            reset,
            theme.muted,
            theme.background,
            hostname,
        });
    }
}
