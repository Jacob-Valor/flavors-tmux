const std = @import("std");
const tmux_renderer = @import("../tmux_renderer.zig");
const WidgetContext = @import("../core/widget.zig").WidgetContext;

fn getDockerContext(allocator: std.mem.Allocator, io: std.Io) !?[]u8 {
    const result = std.process.run(allocator, io, .{
        .argv = &.{
            "docker", "context", "show",
        },
    }) catch return null;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term != .exited or result.term.exited != 0) {
        return null;
    }

    const trimmed = std.mem.trim(u8, result.stdout, " \n\r\t");
    if (trimmed.len == 0) {
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

    var hex_buf: [32]u8 = undefined;
    try writer.print("{s}#[fg={s},bg={s},bold] {s}", .{
        reset,
        tmux_renderer.colorHexString(color, &hex_buf),
        tmux_renderer.colorHexString(theme.background, &hex_buf),
        ctx_str,
    });
}

test "docker WidgetContext initializes" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    var ctx = try WidgetContext.init(gpa, io, &env_map, "hard", false);
    defer ctx.deinit();

    try std.testing.expect(!ctx.theme.muted.isDefault());
    try std.testing.expect(!ctx.theme.info.isDefault());
    try std.testing.expect(!ctx.theme.background.isDefault());
    try std.testing.expect(std.mem.startsWith(u8, ctx.reset, "#[fg="));
}
