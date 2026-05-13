const std = @import("std");
const themes = @import("../themes/registry.zig");

fn getTerraformWorkspace(allocator: std.mem.Allocator, io: std.Io, cwd: []const u8) !?[]u8 {
    const result = std.process.run(allocator, io, .{
        .argv = &.{
            "terraform", "workspace", "show",
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

    const workspace = getTerraformWorkspace(allocator, io, path) catch return;
    defer if (workspace) |w| allocator.free(w);
    const ws = workspace orelse return;

    const reset = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},nobold,noitalics,nounderscore,nodim]", .{
        theme.foreground,
        theme.background,
    });
    defer allocator.free(reset);

    // Color-code: default = muted, else = primary
    const color = if (std.mem.eql(u8, ws, "default")) theme.muted else theme.primary;

    try writer.print("{s}#[fg={s},bg={s},bold]󱁢 {s}", .{
        reset,
        color,
        theme.background,
        ws,
    });
}
