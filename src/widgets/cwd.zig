const std = @import("std");
const WidgetContext = @import("../core/widget.zig").WidgetContext;

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    theme_name: []const u8,
    transparent: bool,
    environ_map: *std.process.Environ.Map,
    cwd: []const u8,
    writer: *std.Io.Writer,
) !void {
    var ctx = try WidgetContext.init(allocator, io, environ_map, theme_name, transparent);
    defer ctx.deinit();
    const theme = ctx.theme;
    const reset = ctx.reset;

    const path = if (cwd.len > 0) cwd else return;

    // Get the basename for display
    const basename = std.fs.path.basename(path);
    if (basename.len == 0) return;

    // Try to get git repo root for relative display
    const git_result = std.process.run(allocator, io, .{
        .argv = &.{
            "git", "rev-parse", "--show-toplevel",
        },
        .cwd = .{ .path = path },
    }) catch null;

    var display_path: []const u8 = basename;
    var display_owned: bool = false;

    if (git_result) |result| {
        defer allocator.free(result.stderr);
        defer allocator.free(result.stdout);
        if (result.term == .exited and result.term.exited == 0) {
            const repo_root = std.mem.trim(u8, result.stdout, " \n\r\t");
            if (repo_root.len > 0) {
                const repo_name = std.fs.path.basename(repo_root);
                if (repo_name.len > 0) {
                    if (std.mem.eql(u8, repo_name, basename)) {
                        display_path = basename;
                    } else {
                        const rel = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ repo_name, basename });
                        display_path = rel;
                        display_owned = true;
                    }
                }
            }
        }
    }
    defer if (display_owned) allocator.free(display_path);

    try writer.print("{s}#[fg={s},bg={s},bold]󰉋 {s}", .{
        reset,
        theme.emphasis,
        theme.background,
        display_path,
    });
}
