const std = @import("std");
const themes = @import("../themes/registry.zig");
const Theme = @import("../core/theme.zig").Theme;

fn getKubectlOutput(allocator: std.mem.Allocator, io: std.Io, argv: []const []const u8) !?[]u8 {
    const result = std.process.run(allocator, io, .{
        .argv = argv,
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

fn contextColor(theme: Theme, context: []const u8) []const u8 {
    var buf: [256]u8 = undefined;
    const ctx_lower = std.ascii.lowerString(&buf, context);
    // Check for production-like names
    if (std.mem.indexOf(u8, ctx_lower, "prod") != null or
        std.mem.indexOf(u8, ctx_lower, "production") != null)
    {
        return theme.danger;
    }
    // Check for staging-like names
    if (std.mem.indexOf(u8, ctx_lower, "stage") != null or
        std.mem.indexOf(u8, ctx_lower, "staging") != null or
        std.mem.indexOf(u8, ctx_lower, "dev") != null or
        std.mem.indexOf(u8, ctx_lower, "development") != null)
    {
        return theme.warning;
    }
    return theme.info;
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

    const context = getKubectlOutput(allocator, io, &.{
        "kubectl", "config", "current-context",
    }) catch return;
    defer if (context) |c| allocator.free(c);
    const ctx = context orelse return;

    const ns_opt = getKubectlOutput(allocator, io, &.{
        "kubectl", "config", "view", "--minify", "--output", "jsonpath={..namespace}",
    }) catch null;
    defer if (ns_opt) |ns| allocator.free(ns);
    const namespace = ns_opt orelse "default";

    const reset = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},nobold,noitalics,nounderscore,nodim]", .{
        theme.foreground,
        theme.background,
    });
    defer allocator.free(reset);

    const color = contextColor(theme, ctx);

    try writer.print("{s}#[fg={s},bg={s},bold]󱃾 {s}/{s}", .{
        reset,
        color,
        theme.background,
        ctx,
        namespace,
    });
}
