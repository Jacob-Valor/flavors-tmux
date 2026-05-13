const std = @import("std");
const Io = std.Io;

const themes = @import("themes/registry.zig");
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
const git_worktree = @import("widgets/git_worktree.zig");
const yadm = @import("widgets/yadm.zig");

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
    \\  git-worktree --theme <name> <path>  Render Git worktree indicator widget
    \\  yadm --theme <name>                 Render YADM dotfiles status widget
    \\  theme <name> <key>                  Look up a theme color
    \\  theme-list                          List available themes
    \\
    \\Options:
    \\  --theme <name>                      Theme name (default: hard)
    \\  --format <12H|24H|hide>             Time format (datetime)
    \\  --name <battery-name>               Battery name (battery)
    \\  --low-threshold <n>                 Low battery threshold (battery, default: 20)
    \\  --cache-ttl <seconds>               Forge widget cache TTL (default: 300)
    \\  --transparent                       Use default terminal background
    \\
    \\Styles for custom-number:
    \\  arabic, fsquare, hsquare, dsquare, super, sub, earabic, hide
    \\
;

fn run(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const raw_args = try init.minimal.args.toSlice(arena);

    if (raw_args.len < 2) {
        std.debug.print("{s}", .{usage});
        return error.Usage;
    }

    const args = try cli.parseArgs(arena, raw_args[1..]);

    const io = init.io;
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    if (std.mem.eql(u8, args.command, "custom-number")) {
        try custom_number.run(arena, args.positional.items, stdout_writer);
    } else if (std.mem.eql(u8, args.command, "datetime")) {
        try datetime.run(arena, args.theme, args.time_format, args.transparent, io, init.environ_map, stdout_writer);
    } else if (std.mem.eql(u8, args.command, "battery")) {
        try battery.run(arena, io, init.environ_map, args.theme, args.transparent, args.battery_name, args.low_threshold, stdout_writer);
    } else if (std.mem.eql(u8, args.command, "git-status")) {
        if (args.positional.items.len < 1) {
            std.debug.print("Usage: flavors-tmux git-status --theme <name> <repo-path>\n", .{});
            return error.Usage;
        }
        try git_status.run(arena, io, init.environ_map, args.theme, args.transparent, args.positional.items[0], stdout_writer);
    } else if (std.mem.eql(u8, args.command, "wb-git-status")) {
        if (args.positional.items.len < 1) {
            std.debug.print("Usage: flavors-tmux wb-git-status --theme <name> <repo-path>\n", .{});
            return error.Usage;
        }
        try wb_git_status.run(arena, io, init.environ_map, args.theme, args.transparent, args.positional.items[0], args.cache_ttl, stdout_writer);
    } else if (std.mem.eql(u8, args.command, "hostname")) {
        try hostname.run(arena, io, args.theme, args.transparent, init.environ_map, stdout_writer);
    } else if (std.mem.eql(u8, args.command, "cpu-memory")) {
        try cpu_memory.run(arena, io, init.environ_map, args.theme, args.transparent, stdout_writer);
    } else if (std.mem.eql(u8, args.command, "kubernetes")) {
        try kubernetes.run(arena, io, args.theme, args.transparent, init.environ_map, stdout_writer);
    } else if (std.mem.eql(u8, args.command, "cwd")) {
        if (args.positional.items.len < 1) {
            std.debug.print("Usage: flavors-tmux cwd --theme <name> <path>\n", .{});
            return error.Usage;
        }
        try cwd.run(arena, io, args.theme, args.transparent, init.environ_map, args.positional.items[0], stdout_writer);
    } else if (std.mem.eql(u8, args.command, "terraform")) {
        if (args.positional.items.len < 1) {
            std.debug.print("Usage: flavors-tmux terraform --theme <name> <path>\n", .{});
            return error.Usage;
        }
        try terraform.run(arena, io, args.theme, args.transparent, init.environ_map, args.positional.items[0], stdout_writer);
    } else if (std.mem.eql(u8, args.command, "docker")) {
        try docker.run(arena, io, args.theme, args.transparent, init.environ_map, stdout_writer);
    } else if (std.mem.eql(u8, args.command, "git-worktree")) {
        if (args.positional.items.len < 1) {
            std.debug.print("Usage: flavors-tmux git-worktree --theme <name> <path>\n", .{});
            return error.Usage;
        }
        try git_worktree.run(arena, io, args.theme, args.transparent, init.environ_map, args.positional.items[0], stdout_writer);
    } else if (std.mem.eql(u8, args.command, "yadm")) {
        try yadm.run(arena, io, args.theme, args.transparent, init.environ_map, stdout_writer);
    } else if (std.mem.eql(u8, args.command, "theme")) {
        if (args.positional.items.len < 2) {
            std.debug.print("Usage: flavors-tmux theme <name> <key>\n", .{});
            return error.Usage;
        }
        const theme = themes.byName(arena, io, init.environ_map, args.positional.items[0]) orelse {
            std.debug.print("Unknown theme: {s}\n", .{args.positional.items[0]});
            return error.UnknownTheme;
        };
        const value = theme.lookup(args.positional.items[1]) orelse {
            std.debug.print("Unknown key: {s}\n", .{args.positional.items[1]});
            return error.UnknownKey;
        };
        try stdout_writer.print("{s}\n", .{value});
    } else if (std.mem.eql(u8, args.command, "theme-list")) {
        for (themes.names) |name| {
            try stdout_writer.print("{s}\n", .{name});
        }
    } else {
        std.debug.print("Unknown command: {s}\n{s}", .{ args.command, usage });
        return error.UnknownCommand;
    }

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
