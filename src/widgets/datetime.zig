const std = @import("std");
const themes = @import("../themes/registry.zig");

const TimeFormat = @import("../cli/args.zig").TimeFormat;

pub fn run(allocator: std.mem.Allocator, theme_name: []const u8, time_format: TimeFormat, transparent: bool, io: std.Io, environ_map: *std.process.Environ.Map, writer: *std.Io.Writer) !void {
    const theme = (themes.byName(allocator, io, environ_map, theme_name) orelse themes.hard).withTransparentBackground(transparent);

    const separator = "▒";
    const time_icon = "󰥔";

    var time_str: []const u8 = "";
    if (time_format != .hide) {
        const fmt = switch (time_format) {
            .H12 => "+%I:%M %p ",
            .H24 => "+%H:%M ",
            .hide => unreachable,
        };

        var buf: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const fba_allocator = fba.allocator();

        const result = try std.process.run(fba_allocator, io, .{
            .argv = &.{ "date", fmt },
        });
        // stdout/stderr live in fba buffer, no need to free

        if (result.term == .exited and result.term.exited == 0) {
            time_str = std.mem.trim(u8, result.stdout, " \n\r\t");
        }
    }

    try writer.print("#[fg={s},bg={s}]{s} #[fg={s}]{s} {s}", .{
        theme.accent,
        theme.surface_alt,
        separator,
        theme.emphasis,
        time_icon,
        time_str,
    });
}
