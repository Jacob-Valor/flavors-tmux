const std = @import("std");
const tmux_renderer = @import("../tmux_renderer.zig");
const util = @import("../core/util.zig");
const WidgetContext = @import("../core/widget.zig").WidgetContext;

fn getYadmStatus(allocator: std.mem.Allocator, io: std.Io) !?util.PorcelainStatus {
    const result = std.process.run(allocator, io, .{
        .argv = &.{
            "yadm", "status", "--porcelain",
        },
    }) catch return null;
    defer allocator.free(result.stderr);

    if (result.term != .exited or result.term.exited != 0) {
        allocator.free(result.stdout);
        return null;
    }

    const parsed = util.parsePorcelain(result.stdout);
    allocator.free(result.stdout);
    return parsed;
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

    const status = getYadmStatus(allocator, io) catch return;
    const st = status orelse return;

    var hex_buf: [32]u8 = undefined;

    // If clean, show muted icon only
    if (st.changed == 0 and st.untracked == 0) {
        try writer.print("{s}#[fg={s},bg={s},bold]󰃣", .{
            reset,
            tmux_renderer.colorHexString(theme.muted, &hex_buf),
            tmux_renderer.colorHexString(theme.background, &hex_buf),
        });
        return;
    }

    // Write status directly to the output writer, avoiding intermediate allocations
    try writer.print("{s}#[fg={s},bg={s},bold]󰃣", .{ reset, tmux_renderer.colorHexString(theme.muted, &hex_buf), tmux_renderer.colorHexString(theme.background, &hex_buf) });

    if (st.changed > 0) {
        try writer.print(" #[fg={s},bg={s},bold] {d}", .{ tmux_renderer.colorHexString(theme.warning, &hex_buf), tmux_renderer.colorHexString(theme.background, &hex_buf), st.changed });
    }

    if (st.untracked > 0) {
        try writer.print(" #[fg={s},bg={s},bold] {d}", .{ tmux_renderer.colorHexString(theme.muted, &hex_buf), tmux_renderer.colorHexString(theme.background, &hex_buf), st.untracked });
    }
}

test "yadm WidgetContext initializes" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    var ctx = try WidgetContext.init(gpa, io, &env_map, "hard", false);
    defer ctx.deinit();

    try std.testing.expect(!ctx.theme.muted.isDefault());
    try std.testing.expect(!ctx.theme.warning.isDefault());
    try std.testing.expect(ctx.theme.background.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, ctx.reset, "#[fg="));
}

test "yadm run returns null when yadm unavailable" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    var buf: [64]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buf);

    // Should not panic when yadm is not installed — just return early
    run(gpa, io, "hard", false, &env_map, &writer) catch {};
}
