const std = @import("std");
const themes = @import("../themes/registry.zig");

pub fn run(theme_name: []const u8, time_format: []const u8, io: std.Io, writer: *std.Io.Writer) !void {
    const theme = themes.byName(theme_name) orelse themes.hard;

    const separator = "▒";
    const time_icon = "󰥔";

    var time_str: []const u8 = "";
    if (!std.mem.eql(u8, time_format, "hide")) {
        const fmt = if (std.mem.eql(u8, time_format, "12H")) "+%I:%M %p " else "+%H:%M ";

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
