const std = @import("std");
const themes = @import("../themes/registry.zig");

fn getYadmStatus(allocator: std.mem.Allocator, io: std.Io) !?struct { changed: usize, untracked: usize } {
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

    var changed: usize = 0;
    var untracked: usize = 0;

    var lines = std.mem.splitScalar(u8, result.stdout, '\n');
    while (lines.next()) |line| {
        if (line.len < 2) continue;
        const first = line[0];
        const second = line[1];
        if (first == 'M' or first == 'A' or first == 'D' or first == 'R' or first == 'C' or first == 'U' or
            second == 'M' or second == 'A' or second == 'D')
        {
            changed += 1;
        } else if (first == '?') {
            untracked += 1;
        }
    }

    allocator.free(result.stdout);
    return .{ .changed = changed, .untracked = untracked };
}

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    theme_name: []const u8,
    transparent: bool,
    environ_map: *std.process.Environ.Map,
    writer: *std.Io.Writer,
) !void {
    const theme = (themes.byName(allocator, io, environ_map, theme_name) orelse themes.hard).withTransparentBackground(transparent);

    const status = getYadmStatus(allocator, io) catch return;
    const st = status orelse return;

    const reset = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},nobold,noitalics,nounderscore,nodim]", .{
        theme.foreground,
        theme.background,
    });
    defer allocator.free(reset);

    // If clean, show muted icon only
    if (st.changed == 0 and st.untracked == 0) {
        try writer.print("{s}#[fg={s},bg={s},bold]󰃣", .{
            reset,
            theme.muted,
            theme.background,
        });
        return;
    }

    // Build status string
    var parts: std.ArrayList(u8) = .empty;
    defer parts.deinit(allocator);

    try parts.appendSlice(allocator, "󰃣 ");

    if (st.changed > 0) {
        const changed_str = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},bold] {d} ", .{
            theme.warning,
            theme.background,
            st.changed,
        });
        defer allocator.free(changed_str);
        try parts.appendSlice(allocator, changed_str);
    }

    if (st.untracked > 0) {
        const untracked_str = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},bold] {d}", .{
            theme.muted,
            theme.background,
            st.untracked,
        });
        defer allocator.free(untracked_str);
        try parts.appendSlice(allocator, untracked_str);
    }

    try writer.print("{s}{s}", .{ reset, parts.items });
}
