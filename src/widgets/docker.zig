const std = @import("std");
const WidgetContext = @import("../core/widget.zig").WidgetContext;

fn getDockerContext(allocator: std.mem.Allocator, io: std.Io) !?[]u8 {
    const result = std.process.run(allocator, io, .{
        .argv = &.{
            "docker", "context", "show",
        },
    }) catch return null;
    defer allocator.free(result.stderr);

    if (result.term != .exited or result.term.exited != 0) {
        allocator.free(result.stdout);
        return null;
    }

    const trimmed = std.mem.trim(u8, result.stdout, " \n\r\t");
    if (trimmed.len == 0) {
        allocator.free(result.stdout);
        return null;
    }

    return try allocator.dupe(u8, trimmed);
}

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

    const context = getDockerContext(allocator, io) catch return;
    defer if (context) |c| allocator.free(c);
    const ctx_str = context orelse return;

    // Color-code: default = muted, else = info
    const color = if (std.mem.eql(u8, ctx_str, "default")) theme.muted else theme.info;

    try writer.print("{s}#[fg={s},bg={s},bold] {s}", .{
        reset,
        color,
        theme.background,
        ctx_str,
    });
}
