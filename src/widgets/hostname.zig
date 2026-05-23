const std = @import("std");
const WidgetContext = @import("../core/widget.zig").WidgetContext;

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    theme_name: []const u8,
    transparent: bool,
    environ_map: *std.process.Environ.Map,
    writer: *std.Io.Writer,
) !void {
    var ctx = try WidgetContext.init(allocator, io, environ_map, theme_name, transparent);
    defer ctx.deinit();
    const theme = ctx.theme;
    const reset = ctx.reset;

    const is_ssh = environ_map.get("SSH_CONNECTION") != null or environ_map.get("SSH_CLIENT") != null;

    // Prefer the HOSTNAME env var (reliable on most systems), falling back to gethostname.
    const hostname = if (environ_map.get("HOSTNAME")) |h|
        h
    else blk: {
        var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
        break :blk std.posix.gethostname(&buf) catch "unknown";
    };

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
