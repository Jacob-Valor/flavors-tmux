const std = @import("std");
const tui = @import("tui");
const Color = tui.Color;
const tmux_renderer = @import("../tmux_renderer.zig");
const themes = @import("../themes/registry.zig");
const Theme = @import("../core/theme.zig").Theme;
const cli = @import("../cli/args.zig");
const datetime = @import("datetime.zig");

const git_status = @import("git_status.zig");
const wb_git_status = @import("wb_git_status.zig");
const cpu_memory = @import("cpu_memory.zig");
const hostname = @import("hostname.zig");
const battery_mod = @import("battery.zig");
const kubernetes = @import("kubernetes.zig");
const cwd = @import("cwd.zig");
const terraform = @import("terraform.zig");
const docker_mod = @import("docker.zig");
const yadm = @import("yadm.zig");
const gpg_ssh_agent = @import("gpg_ssh_agent.zig");
const ai_assistant = @import("ai_assistant.zig");

const WidgetColor = enum {
    emphasis,
    success,
    accent,
    info,
    danger,
    accent_bright,
    primary,
    primary_bright,
    warning,
};

const WidgetEntry = struct {
    color: WidgetColor,
    no_sep: bool = false,
};

fn lookupEntry(name: []const u8) ?WidgetEntry {
    if (std.mem.eql(u8, name, "cwd")) return .{ .color = .emphasis };
    if (std.mem.eql(u8, name, "git")) return .{ .color = .success };
    if (std.mem.eql(u8, name, "wb-git")) return .{ .color = .accent, .no_sep = true };
    if (std.mem.eql(u8, name, "docker")) return .{ .color = .info, .no_sep = true };
    if (std.mem.eql(u8, name, "battery")) return .{ .color = .danger };
    if (std.mem.eql(u8, name, "hostname")) return .{ .color = .info };
    if (std.mem.eql(u8, name, "cpu")) return .{ .color = .accent_bright };
    if (std.mem.eql(u8, name, "kubernetes")) return .{ .color = .info };
    if (std.mem.eql(u8, name, "terraform")) return .{ .color = .primary };
    if (std.mem.eql(u8, name, "yadm")) return .{ .color = .accent };
    if (std.mem.eql(u8, name, "gpg-ssh")) return .{ .color = .primary_bright };
    if (std.mem.eql(u8, name, "ai-assistant")) return .{ .color = .success };
    if (std.mem.eql(u8, name, "datetime")) return .{ .color = .warning };
    return null;
}

fn colorFromTheme(theme: Theme, wc: WidgetColor) Color {
    return switch (wc) {
        .emphasis => theme.emphasis,
        .success => theme.success,
        .accent => theme.accent,
        .info => theme.info,
        .danger => theme.danger,
        .accent_bright => theme.accent_bright,
        .primary => theme.primary,
        .primary_bright => theme.primary_bright,
        .warning => theme.warning,
    };
}

fn renderWidget(
    arena: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
    theme_name: []const u8,
    transparent: bool,
    pane_path: []const u8,
    widget_name: []const u8,
    battery_name: ?[]const u8,
    low_threshold: u8,
    time_format: cli.TimeFormat,
    cache_ttl: u64,
) ?[]const u8 {
    var buf: [4096]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buf);

    if (std.mem.eql(u8, widget_name, "cwd")) {
        cwd.run(arena, io, theme_name, transparent, environ_map, pane_path, &writer) catch return null;
    } else if (std.mem.eql(u8, widget_name, "git")) {
        git_status.run(arena, io, environ_map, theme_name, transparent, pane_path, &writer) catch return null;
    } else if (std.mem.eql(u8, widget_name, "wb-git")) {
        wb_git_status.run(arena, io, environ_map, theme_name, transparent, pane_path, cache_ttl, &writer) catch return null;
    } else if (std.mem.eql(u8, widget_name, "cpu")) {
        cpu_memory.run(arena, io, environ_map, theme_name, transparent, &writer) catch return null;
    } else if (std.mem.eql(u8, widget_name, "hostname")) {
        hostname.run(arena, io, theme_name, transparent, environ_map, &writer) catch return null;
    } else if (std.mem.eql(u8, widget_name, "datetime")) {
        datetime.run(arena, theme_name, time_format, transparent, io, environ_map, &writer) catch return null;
    } else if (std.mem.eql(u8, widget_name, "battery")) {
        battery_mod.run(arena, io, environ_map, theme_name, transparent, battery_name, low_threshold, &writer) catch return null;
    } else if (std.mem.eql(u8, widget_name, "kubernetes")) {
        kubernetes.run(arena, io, theme_name, transparent, environ_map, &writer) catch return null;
    } else if (std.mem.eql(u8, widget_name, "terraform")) {
        terraform.run(arena, io, theme_name, transparent, environ_map, pane_path, &writer) catch return null;
    } else if (std.mem.eql(u8, widget_name, "docker")) {
        docker_mod.run(arena, io, theme_name, transparent, environ_map, &writer) catch return null;
    } else if (std.mem.eql(u8, widget_name, "yadm")) {
        yadm.run(arena, io, theme_name, transparent, environ_map, &writer) catch return null;
    } else if (std.mem.eql(u8, widget_name, "gpg-ssh")) {
        gpg_ssh_agent.run(arena, io, environ_map, theme_name, transparent, &writer) catch return null;
    } else if (std.mem.eql(u8, widget_name, "ai-assistant")) {
        ai_assistant.run(arena, io, environ_map, theme_name, transparent, &writer) catch return null;
    } else return null;

    const output = std.Io.Writer.buffered(&writer);
    if (output.len == 0) return null;
    return arena.dupe(u8, output) catch null;
}

pub fn run(
    arena: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
    theme_name: []const u8,
    transparent: bool,
    pane_path: ?[]const u8,
    show_names: []const []const u8,
    battery_name: ?[]const u8,
    low_threshold: u8,
    time_format_str: []const u8,
    cache_ttl: u64,
    writer: *std.Io.Writer,
) !void {
    const time_format = cli.TimeFormat.fromString(time_format_str) orelse .H24;
    const theme = (themes.byName(arena, io, environ_map, theme_name) orelse themes.hard).withTransparentBackground(transparent);
    const path = pane_path orelse ".";

    var outputs: std.ArrayList(struct { text: []const u8, color: WidgetColor, no_sep: bool }) = .empty;
    defer outputs.deinit(arena);

    for (show_names) |name| {
        const entry = lookupEntry(name) orelse continue;
        if (renderWidget(arena, io, environ_map, theme_name, transparent, path, name, battery_name, low_threshold, time_format, cache_ttl)) |output| {
            try outputs.append(arena, .{ .text = output, .color = entry.color, .no_sep = entry.no_sep });
        }
    }

    if (outputs.items.len == 0) return;

    var prev_no_sep: bool = false;
    for (outputs.items, 0..) |item, i| {
        if (i > 0 and !prev_no_sep and !item.no_sep) {
            try writer.writeAll(" ");
        }
        var fg_buf: [32]u8 = undefined;
        var bg_buf: [32]u8 = undefined;
        try writer.print("#[fg={s},bg={s}]", .{ tmux_renderer.colorHexString(colorFromTheme(theme, item.color), &fg_buf), tmux_renderer.colorHexString(theme.surface_alt, &bg_buf) });
        try writer.writeAll(item.text);
        prev_no_sep = item.no_sep;
    }
}

test "lookupEntry returns correct colors for all widget names" {
    const cases = [_]struct { name: []const u8, color: WidgetColor, no_sep: bool }{
        .{ .name = "cwd", .color = .emphasis, .no_sep = false },
        .{ .name = "git", .color = .success, .no_sep = false },
        .{ .name = "wb-git", .color = .accent, .no_sep = true },
        .{ .name = "docker", .color = .info, .no_sep = true },
        .{ .name = "battery", .color = .danger, .no_sep = false },
        .{ .name = "hostname", .color = .info, .no_sep = false },
        .{ .name = "cpu", .color = .accent_bright, .no_sep = false },
        .{ .name = "kubernetes", .color = .info, .no_sep = false },
        .{ .name = "terraform", .color = .primary, .no_sep = false },
        .{ .name = "yadm", .color = .accent, .no_sep = false },
        .{ .name = "gpg-ssh", .color = .primary_bright, .no_sep = false },
        .{ .name = "ai-assistant", .color = .success, .no_sep = false },
        .{ .name = "datetime", .color = .warning, .no_sep = false },
    };

    for (cases) |c| {
        const entry = lookupEntry(c.name) orelse return error.TestFailed;
        try std.testing.expectEqual(c.color, entry.color);
        try std.testing.expectEqual(c.no_sep, entry.no_sep);
    }

    try std.testing.expectEqual(@as(@TypeOf(lookupEntry("")), null), lookupEntry("nonexistent"));
}

test "colorFromTheme maps WidgetColor to correct Theme fields" {
    const theme = themes.hard;
    try std.testing.expect(std.meta.eql(theme.emphasis, colorFromTheme(theme, .emphasis)));
    try std.testing.expect(std.meta.eql(theme.success, colorFromTheme(theme, .success)));
    try std.testing.expect(std.meta.eql(theme.accent, colorFromTheme(theme, .accent)));
    try std.testing.expect(std.meta.eql(theme.info, colorFromTheme(theme, .info)));
    try std.testing.expect(std.meta.eql(theme.danger, colorFromTheme(theme, .danger)));
    try std.testing.expect(std.meta.eql(theme.accent_bright, colorFromTheme(theme, .accent_bright)));
    try std.testing.expect(std.meta.eql(theme.primary, colorFromTheme(theme, .primary)));
    try std.testing.expect(std.meta.eql(theme.primary_bright, colorFromTheme(theme, .primary_bright)));
    try std.testing.expect(std.meta.eql(theme.warning, colorFromTheme(theme, .warning)));
}

test "status run produces empty output for empty widget list" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    var buf: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buf);

    try run(gpa, io, &env_map, "hard", false, null, &.{}, null, 20, "24H", 300, &writer);
    try std.testing.expectEqual(@as(usize, 0), std.Io.Writer.buffered(&writer).len);
}

test "status run handles unknown widget names gracefully" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    var buf: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buf);

    try run(gpa, io, &env_map, "hard", false, null, &.{ "nonexistent", "also-fake" }, null, 20, "24H", 300, &writer);
    try std.testing.expectEqual(@as(usize, 0), std.Io.Writer.buffered(&writer).len);
}
