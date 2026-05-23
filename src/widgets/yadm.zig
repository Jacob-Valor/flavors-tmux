const std = @import("std");
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

    // If clean, show muted icon only
    if (st.changed == 0 and st.untracked == 0) {
        try writer.print("{s}#[fg={s},bg={s},bold]󰃣", .{
            reset,
            theme.muted,
            theme.background,
        });
        return;
    }

    // Write status directly to the output writer, avoiding intermediate allocations
    try writer.print("{s}#[fg={s},bg={s},bold]󰃣", .{ reset, theme.muted, theme.background });

    if (st.changed > 0) {
        try writer.print(" #[fg={s},bg={s},bold] {d}", .{ theme.warning, theme.background, st.changed });
    }

    if (st.untracked > 0) {
        try writer.print(" #[fg={s},bg={s},bold] {d}", .{ theme.muted, theme.background, st.untracked });
    }
}
