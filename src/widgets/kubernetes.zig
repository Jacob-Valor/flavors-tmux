const std = @import("std");
const themes = @import("../themes/registry.zig");
const Theme = @import("../core/theme.zig").Theme;
const WidgetContext = @import("../core/widget.zig").WidgetContext;

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

fn contextContains(theme: Theme, context: []const u8, needle: []const u8) ?[]const u8 {
    if (std.ascii.indexOfIgnoreCase(context, needle) != null) return theme.danger;
    return null;
}

fn contextColor(theme: Theme, context: []const u8) []const u8 {
    // Check for production-like names
    if (contextContains(theme, context, "prod")) |color| return color;
    if (contextContains(theme, context, "production")) |color| return color;
    // Check for staging-like names
    if (contextContains(theme, context, "stage")) |color| return color;
    if (contextContains(theme, context, "staging")) |color| return color;
    if (contextContains(theme, context, "dev")) |color| return color;
    if (contextContains(theme, context, "development")) |color| return color;
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
