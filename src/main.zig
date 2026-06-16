const std = @import("std");
const Io = std.Io;

const themes = @import("themes/registry.zig");
const tmux_renderer = @import("tmux_renderer.zig");
const cli = @import("cli/args.zig");
const custom_number = @import("widgets/custom_number.zig");
const datetime = @import("widgets/datetime.zig");
const battery = @import("widgets/battery.zig");
const git_status = @import("widgets/git_status.zig");
const wb_git_status = @import("widgets/wb_git_status.zig");
const hostname = @import("widgets/hostname.zig");
const cpu_memory = @import("widgets/cpu_memory.zig");
const kubernetes = @import("widgets/kubernetes.zig");
const cwd = @import("widgets/cwd.zig");
const terraform = @import("widgets/terraform.zig");
const docker = @import("widgets/docker.zig");
const yadm = @import("widgets/yadm.zig");
const gpg_ssh_agent = @import("widgets/gpg_ssh_agent.zig");
const ai_assistant = @import("widgets/ai_assistant.zig");
const status_mod = @import("widgets/status.zig");

const usage =
    \\Usage: flavors-tmux <command> [options]
    \\
    \\Commands:
    \\  custom-number <id> <style>          Format a number with a glyph style
    \\  datetime --theme <name> [opts]      Render datetime widget
    \\  battery --theme <name> [opts]       Render battery widget
    \\  git-status --theme <name> <path>    Render git status widget
    \\  wb-git-status --theme <name> <path> Render GitHub/GitLab status widget
    \\  hostname --theme <name>             Render hostname/SSH indicator widget
    \\  cpu-memory --theme <name>           Render CPU and memory usage widget
    \\  kubernetes --theme <name>           Render Kubernetes context widget
    \\  cwd --theme <name> <path>           Render current working directory widget
    \\  terraform --theme <name> <path>     Render Terraform workspace widget
    \\  docker --theme <name>               Render Docker context widget
  \\  yadm --theme <name>                 Render YADM dotfiles status widget
  \\  gpg-ssh-agent --theme <name>       Render GPG/SSH agent status widget
  \\  theme <name> <key>                  Look up a theme color
    \\  theme-list                          List available themes
    \\
    \\Options:
    \\  --theme <name>                      Theme name (default: hard)
    \\  --format <12H|24H|hide>             Time format (datetime)
    \\  --name <battery-name>               Battery name (battery)
    \\  --low-threshold <n>                 Low battery threshold (battery, default: 20)
    \\  -c, --cache-ttl <seconds>           Forge widget cache TTL (default: 300)
    \\  --transparent                       Use default terminal background
    \\
    \\Styles for custom-number:
    \\  arabic, fsquare, hsquare, dsquare, super, sub, earabic, hide
    \\
;

const HandlerFn = *const fn(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
    args: *const cli.Args,
    stderr_writer: *std.Io.Writer,
    stdout_writer: *std.Io.Writer,
) anyerror!void;

fn handleCustomNumber(arena: std.mem.Allocator, _: std.Io, _: *std.process.Environ.Map, args: *const cli.Args, _: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    try custom_number.run(arena, args.positional.items, stdout);
}

fn handleDatetime(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, _: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    try datetime.run(arena, args.theme, args.time_format, args.transparent, io, env, stdout);
}

fn handleBattery(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, _: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    try battery.run(arena, io, env, args.theme, args.transparent, args.battery_name, args.low_threshold, stdout);
}

fn handleGitStatus(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, stderr: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    if (args.positional.items.len < 1) {
        try stderr.print("Usage: flavors-tmux git-status --theme <name> <repo-path>\n", .{});
        return error.Usage;
    }
    try git_status.run(arena, io, env, args.theme, args.transparent, args.positional.items[0], stdout);
}

fn handleWbGitStatus(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, stderr: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    if (args.positional.items.len < 1) {
        try stderr.print("Usage: flavors-tmux wb-git-status --theme <name> <repo-path>\n", .{});
        return error.Usage;
    }
    try wb_git_status.run(arena, io, env, args.theme, args.transparent, args.positional.items[0], args.cache_ttl, stdout);
}

fn handleHostname(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, _: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    try hostname.run(arena, io, args.theme, args.transparent, env, stdout);
}

fn handleCpuMemory(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, _: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    try cpu_memory.run(arena, io, env, args.theme, args.transparent, stdout);
}

fn handleKubernetes(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, _: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    try kubernetes.run(arena, io, args.theme, args.transparent, env, stdout);
}

fn handleCwd(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, stderr: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    if (args.positional.items.len < 1) {
        try stderr.print("Usage: flavors-tmux cwd --theme <name> <path>\n", .{});
        return error.Usage;
    }
    try cwd.run(arena, io, args.theme, args.transparent, env, args.positional.items[0], stdout);
}

fn handleTerraform(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, stderr: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    if (args.positional.items.len < 1) {
        try stderr.print("Usage: flavors-tmux terraform --theme <name> <path>\n", .{});
        return error.Usage;
    }
    try terraform.run(arena, io, args.theme, args.transparent, env, args.positional.items[0], stdout);
}

fn handleDocker(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, _: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    try docker.run(arena, io, args.theme, args.transparent, env, stdout);
}

fn handleYadm(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, _: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    try yadm.run(arena, io, args.theme, args.transparent, env, stdout);
}

fn handleGpgSshAgent(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, _: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    try gpg_ssh_agent.run(arena, io, env, args.theme, args.transparent, stdout);
}

fn handleAiAssistant(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, _: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    try ai_assistant.run(arena, io, env, args.theme, args.transparent, stdout);
}

fn handleStatus(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, stderr: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    if (args.positional.items.len < 1) {
        try stderr.print("Usage: flavors-tmux status --theme <name> --show <widgets> [--pane-path <path>]\n", .{});
        return error.Usage;
    }
    const show_str = args.positional.items[0];
    var show_names: [16][]const u8 = undefined;
    var count: usize = 0;
    var it = std.mem.splitScalar(u8, show_str, ',');
    while (it.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " \t");
        if (trimmed.len > 0 and count < show_names.len) {
            show_names[count] = trimmed;
            count += 1;
        }
    }
    try status_mod.run(arena, io, env, args.theme, args.transparent, args.pane_path, show_names[0..count], args.battery_name, args.low_threshold, args.time_format.toString(), args.cache_ttl, stdout);
}

fn handleTheme(arena: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, args: *const cli.Args, stderr: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    if (args.positional.items.len < 2) {
        try stderr.print("Usage: flavors-tmux theme <name> <key>\n", .{});
        return error.Usage;
    }
    const theme = themes.byName(arena, io, env, args.positional.items[0]) orelse {
        try stderr.print("Unknown theme: {s}\n", .{args.positional.items[0]});
        return error.UnknownTheme;
    };
    const value = theme.lookup(args.positional.items[1]) orelse {
        try stderr.print("Unknown key: {s}\n", .{args.positional.items[1]});
        return error.UnknownKey;
    };
    var hex_buf: [32]u8 = undefined;
    try stdout.print("{s}\n", .{tmux_renderer.colorHexString(value, &hex_buf)});
}

fn handleThemeList(_: std.mem.Allocator, _: std.Io, _: *std.process.Environ.Map, _: *const cli.Args, _: *std.Io.Writer, stdout: *std.Io.Writer) !void {
    for (themes.names) |name| {
        try stdout.print("{s}\n", .{name});
    }
}

const handlers = std.StaticStringMap(HandlerFn).initComptime(.{
    .{ "custom-number", &handleCustomNumber },
    .{ "datetime", &handleDatetime },
    .{ "battery", &handleBattery },
    .{ "git-status", &handleGitStatus },
    .{ "wb-git-status", &handleWbGitStatus },
    .{ "hostname", &handleHostname },
    .{ "cpu-memory", &handleCpuMemory },
    .{ "kubernetes", &handleKubernetes },
    .{ "cwd", &handleCwd },
    .{ "terraform", &handleTerraform },
    .{ "docker", &handleDocker },
    .{ "yadm", &handleYadm },
    .{ "gpg-ssh-agent", &handleGpgSshAgent },
    .{ "ai-assistant", &handleAiAssistant },
    .{ "status", &handleStatus },
    .{ "theme", &handleTheme },
    .{ "theme-list", &handleThemeList },
});

fn run(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const raw_args = try init.minimal.args.toSlice(arena);

    const io = init.io;
    var stderr_buffer: [4096]u8 = undefined;
    var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
    const stderr_writer = &stderr_file_writer.interface;
    defer stderr_writer.flush() catch {};

    if (raw_args.len < 2) {
        try stderr_writer.print("{s}", .{usage});
        return error.Usage;
    }

    const args = cli.parseArgs(arena, raw_args[1..]) catch |err| {
        try stderr_writer.print("{s}", .{usage});
        return err;
    };

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const handler = handlers.get(args.command) orelse {
        try stderr_writer.print("Unknown command: {s}\n{s}", .{ args.command, usage });
        return error.UnknownCommand;
    };
    try handler(arena, io, init.environ_map, &args, stderr_writer, stdout_writer);

    try stdout_writer.flush();
}

pub fn main(init: std.process.Init) void {
    run(init) catch |err| switch (err) {
        error.Usage => std.process.exit(2),
        error.UnknownCommand => std.process.exit(3),
        error.UnknownTheme => std.process.exit(4),
        error.UnknownKey => std.process.exit(5),
        error.MissingValue => std.process.exit(6),
        error.UnknownOption => std.process.exit(7),
        error.InvalidNumber => std.process.exit(8),
        error.InvalidFormat => std.process.exit(9),
        else => std.process.exit(1),
    };
}
