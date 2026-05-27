const std = @import("std");
const WidgetContext = @import("../core/widget.zig").WidgetContext;

/// Check whether the SSH agent is running and count loaded keys.
/// Returns `null` when the agent socket is absent or the command fails,
/// `0` when the agent is running with no identities, and `>0` for the key count.
fn checkSSHAgent(allocator: std.mem.Allocator, io: std.Io, environ_map: *std.process.Environ.Map) ?usize {
    if (environ_map.get("SSH_AUTH_SOCK") == null) return null;

    const result = std.process.run(allocator, io, .{
        .argv = &.{ "ssh-add", "-l" },
    }) catch return null;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const trimmed = std.mem.trim(u8, result.stdout, " \n\r\t");
    if (trimmed.len == 0) return 0;
    // ssh-add -l prints "The agent has no identities." when empty.
    if (std.mem.indexOf(u8, trimmed, "no identities") != null) return 0;

    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, trimmed, '\n');
    while (lines.next()) |line| {
        if (line.len > 0) count += 1;
    }
    return count;
}

/// Check whether the GPG agent is running by attempting a connection.
fn checkGPGAgent(allocator: std.mem.Allocator, io: std.Io) bool {
    const result = std.process.run(allocator, io, .{
        .argv = &.{ "gpg-connect-agent", "--quiet", "/bye" },
    }) catch return false;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return result.term == .exited and result.term.exited == 0;
}

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
    theme_name: []const u8,
    transparent: bool,
    writer: *std.Io.Writer,
) !void {
    var ctx = try WidgetContext.init(allocator, io, environ_map, theme_name, transparent);
    defer ctx.deinit();
    const theme = ctx.theme;
    const reset = ctx.reset;

    const ssh_count = checkSSHAgent(allocator, io, environ_map);
    const gpg_running = checkGPGAgent(allocator, io);

    if (ssh_count == null and !gpg_running) return;

    var first = true;

    if (ssh_count) |count| {
        const color = if (count > 0) theme.success else theme.warning;
        try writer.print("{s}#[fg={s},bg={s},bold] {d}", .{ reset, color, theme.background, count });
        first = false;
    }

    if (gpg_running) {
        if (!first) try writer.print(" ", .{});
        try writer.print("{s}#[fg={s},bg={s},bold]", .{ reset, theme.success, theme.background });
    }
}

test "gpg_ssh_agent WidgetContext initializes" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    var ctx = try WidgetContext.init(gpa, io, &env_map, "hard", false);
    defer ctx.deinit();

    try std.testing.expect(ctx.theme.success.len > 0);
    try std.testing.expect(ctx.theme.warning.len > 0);
    try std.testing.expect(ctx.theme.background.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, ctx.reset, "#[fg="));
}
