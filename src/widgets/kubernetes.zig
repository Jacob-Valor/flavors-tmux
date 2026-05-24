const std = @import("std");
const themes = @import("../themes/registry.zig");
const Theme = @import("../core/theme.zig").Theme;
const WidgetContext = @import("../core/widget.zig").WidgetContext;

fn getKubectlOutput(allocator: std.mem.Allocator, io: std.Io, argv: []const []const u8) !?[]u8 {
    const result = std.process.run(allocator, io, .{
        .argv = argv,
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

fn contextContains(context: []const u8, needle: []const u8) bool {
    return std.ascii.indexOfIgnoreCase(context, needle) != null;
}

fn contextMatchesAny(context: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (contextContains(context, needle)) return true;
    }
    return false;
}

fn contextColor(theme: Theme, context: []const u8) []const u8 {
    if (contextMatchesAny(context, &.{ "prod", "production" })) return theme.danger;
    if (contextMatchesAny(context, &.{ "stage", "staging", "dev", "development" })) return theme.warning;
    return theme.info;
}

test "contextColor maps environment names semantically" {
    const theme = themes.hard;
    try std.testing.expectEqualStrings(theme.danger, contextColor(theme, "prod-cluster"));
    try std.testing.expectEqualStrings(theme.warning, contextColor(theme, "staging-cluster"));
    try std.testing.expectEqualStrings(theme.warning, contextColor(theme, "dev-cluster"));
    try std.testing.expectEqualStrings(theme.info, contextColor(theme, "sandbox"));
}

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    theme_name: []const u8,
    transparent: bool,
    environ_map: *std.process.Environ.Map,
    writer: *std.Io.Writer,
) !void {
    var ctx_widget = try WidgetContext.init(allocator, io, environ_map, theme_name, transparent);
    defer ctx_widget.deinit();
    const theme = ctx_widget.theme;
    const reset = ctx_widget.reset;

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

    const color = contextColor(theme, ctx);

    try writer.print("{s}#[fg={s},bg={s},bold]󱃾 {s}/{s}", .{
        reset,
        color,
        theme.background,
        ctx,
        namespace,
    });
}
