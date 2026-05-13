const std = @import("std");
const themes = @import("../themes/registry.zig");

fn getCurrentBranch(allocator: std.mem.Allocator, io: std.Io, cwd: []const u8) !?[]u8 {
    const result = std.process.run(allocator, io, .{
        .argv = &.{
            "git", "rev-parse", "--abbrev-ref", "HEAD",
        },
        .cwd = .{ .path = cwd },
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

fn isLinkedWorktree(allocator: std.mem.Allocator, io: std.Io, cwd: []const u8) !bool {
    const result = std.process.run(allocator, io, .{
        .argv = &.{
            "git", "rev-parse", "--git-common-dir",
        },
        .cwd = .{ .path = cwd },
    }) catch return false;
    defer allocator.free(result.stderr);

    if (result.term != .exited or result.term.exited != 0) {
        allocator.free(result.stdout);
        return false;
    }

    const common_dir = std.mem.trim(u8, result.stdout, " \n\r\t");
    defer allocator.free(result.stdout);

    return !std.mem.eql(u8, common_dir, ".git");
}

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    theme_name: []const u8,
    transparent: bool,
    environ_map: *std.process.Environ.Map,
    cwd: []const u8,
    writer: *std.Io.Writer,
) !void {
    const theme = (themes.byName(allocator, io, environ_map, theme_name) orelse themes.hard).withTransparentBackground(transparent);

    const path = if (cwd.len > 0) cwd else return;

    const branch = getCurrentBranch(allocator, io, path) catch return;
    const br = branch orelse return;
    defer allocator.free(br);

    const is_worktree = try isLinkedWorktree(allocator, io, path);

    const reset = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},nobold,noitalics,nounderscore,nodim]", .{
        theme.foreground,
        theme.background,
    });
    defer allocator.free(reset);

    const icon = if (is_worktree) "󰙀" else "";
    const color = if (is_worktree) theme.warning else theme.success;

    try writer.print("{s}#[fg={s},bg={s},bold]{s} {s}", .{
        reset,
        color,
        theme.background,
        icon,
        br,
    });
}
