const std = @import("std");
const tui = @import("tui");
const tmux_renderer = @import("../tmux_renderer.zig");
const WidgetContext = @import("../core/widget.zig").WidgetContext;

const Style = tui.Style;
const Color = tui.Color;

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

    const hostname = if (environ_map.get("HOSTNAME")) |h|
        h
    else blk: {
        var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
        break :blk std.posix.gethostname(&buf) catch "unknown";
    };

    // Write reset prefix
    try writer.writeAll(reset);

    if (is_ssh) {
        try tmux_renderer.writeStyle(
            Style.default.setFg(theme.warning).setBg(theme.background).bold(),
            writer,
        );
        try writer.print("▒ 󰣀 {s}", .{hostname});
    } else {
        try tmux_renderer.writeStyle(
            Style.default.setFg(theme.muted).setBg(theme.background).bold(),
            writer,
        );
        try writer.print("▒ 󰌽 {s}", .{hostname});
    }
}

test "hostname WidgetContext initializes" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    var ctx = try WidgetContext.init(gpa, io, &env_map, "hard", false);
    defer ctx.deinit();

    try std.testing.expect(!ctx.theme.muted.isDefault());
    try std.testing.expect(!ctx.theme.warning.isDefault());
    try std.testing.expect(!ctx.theme.background.isDefault());
    try std.testing.expect(std.mem.startsWith(u8, ctx.reset, "#[fg="));
}

test "hostname produces output with expected format" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    var buf: [2048]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buf);

    run(gpa, io, "hard", false, &env_map, &writer) catch return error.SkipZigTest;
    const output = std.Io.Writer.buffered(&writer);

    try std.testing.expect(output.len > 0);
    try std.testing.expect(std.mem.containsAtLeast(u8, output, 1, "#[fg="));
    try std.testing.expect(std.mem.containsAtLeast(u8, output, 1, "󰌽") or std.mem.containsAtLeast(u8, output, 1, "󰣀"));
}
