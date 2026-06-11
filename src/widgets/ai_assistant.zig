const std = @import("std");
const tmux_renderer = @import("../tmux_renderer.zig");
const WidgetContext = @import("../core/widget.zig").WidgetContext;

const Assistant = struct {
    name: []const u8,
    processes: []const []const u8,
};

const known_assistants = [_]Assistant{
    .{ .name = "claude", .processes = &.{"claude"} },
    .{ .name = "aider", .processes = &.{"aider"} },
    .{ .name = "copilot", .processes = &.{"github-copilot"} },
    .{ .name = "ollama", .processes = &.{"ollama"} },
    .{ .name = "cursor", .processes = &.{"cursor"} },
    .{ .name = "codeium", .processes = &.{"codeium"} },
    .{ .name = "windsurf", .processes = &.{"windsurf"} },
    .{ .name = "gemini", .processes = &.{"gemini"} },
    .{ .name = "lmstudio", .processes = &.{"lmstudio"} },
    .{ .name = "continue", .processes = &.{"continue"} },
    .{ .name = "opencode", .processes = &.{"opencode"} },
    .{ .name = "pi", .processes = &.{"pi-coding-agent"} },
    .{ .name = "commandcode", .processes = &.{"commandcode"} },
};

fn isProcessRunning(allocator: std.mem.Allocator, io: std.Io, process_names: []const []const u8) bool {
    for (process_names) |proc_name| {
        const result = std.process.run(allocator, io, .{
            .argv = &.{ "pgrep", "-x", proc_name },
        }) catch continue;
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        if (result.term == .exited and result.term.exited == 0) {
            return true;
        }
    }
    return false;
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

    var active_buf: [256]u8 = undefined;
    var active_len: usize = 0;
    var active_count: usize = 0;

    for (known_assistants) |assistant| {
        if (isProcessRunning(allocator, io, assistant.processes)) {
            if (active_count > 0) {
                if (active_len + 1 <= active_buf.len) {
                    active_buf[active_len] = ',';
                    active_len += 1;
                }
            }
            const copy_len = @min(assistant.name.len, active_buf.len - active_len);
            if (copy_len > 0) {
                @memcpy(active_buf[active_len .. active_len + copy_len], assistant.name[0..copy_len]);
                active_len += copy_len;
            }
            active_count += 1;
        }
    }

    if (active_count == 0) {
        return;
    }

    const assistant_list = active_buf[0..active_len];
    var hex_buf: [32]u8 = undefined;

    try writer.print("{s}#[fg={s},bg={s},bold]▒   {s}", .{
        reset,
        tmux_renderer.colorHexString(theme.success, &hex_buf),
        tmux_renderer.colorHexString(theme.background, &hex_buf),
        assistant_list,
    });
}

test "known_assistants list is not empty" {
    try std.testing.expect(known_assistants.len > 0);
}

test "Assistant struct has name and processes" {
    const assistant = known_assistants[0];
    try std.testing.expect(assistant.name.len > 0);
    try std.testing.expect(assistant.processes.len > 0);
}

test "includes opencode, pi, and commandcode" {
    var found_opencode = false;
    var found_pi = false;
    var found_commandcode = false;
    for (known_assistants) |assistant| {
        if (std.mem.eql(u8, assistant.name, "opencode")) found_opencode = true;
        if (std.mem.eql(u8, assistant.name, "pi")) found_pi = true;
        if (std.mem.eql(u8, assistant.name, "commandcode")) found_commandcode = true;
    }
    try std.testing.expect(found_opencode);
    try std.testing.expect(found_pi);
    try std.testing.expect(found_commandcode);
}
