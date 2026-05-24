const std = @import("std");
const themes = @import("../themes/registry.zig");

const TimeFormat = @import("../cli/args.zig").TimeFormat;

// Cache the formatted time string within a single process invocation.
// Note: tmux #() spawns a fresh process per refresh, so this only helps
// if the same binary is reused within the same minute (e.g., multiple
// widgets invoked in one batch). The primary benefit is avoiding the
// `date` fork when the binary handles multiple datetime calls.
var last_minute_of_day: u16 = 0xFFFF;
var cached_time: [32]u8 = undefined;
var cached_len: usize = 0;

pub fn run(allocator: std.mem.Allocator, theme_name: []const u8, time_format: TimeFormat, transparent: bool, io: std.Io, environ_map: *std.process.Environ.Map, writer: *std.Io.Writer) !void {
    const theme = (themes.byName(allocator, io, environ_map, theme_name) orelse themes.hard).withTransparentBackground(transparent);

    const separator = "▒";
    const time_icon = "󰥔";

    var time_str: []const u8 = "";
    if (time_format != .hide) {
        const now = std.Io.Timestamp.now(io, .real);
        const total_seconds: u64 = @intCast(@divFloor(now.nanoseconds, std.time.ns_per_s));
        const current_minute: u16 = @intCast((total_seconds / 60) % 1440);

        if (current_minute == last_minute_of_day) {
            time_str = cached_time[0..cached_len];
        } else {
            const fmt = switch (time_format) {
                .H12 => "+%I:%M %p ",
                .H24 => "+%H:%M ",
                .hide => unreachable,
            };

            var buf: [4096]u8 = undefined;
            var fba = std.heap.FixedBufferAllocator.init(&buf);
            const fba_allocator = fba.allocator();

            const result = std.process.run(fba_allocator, io, .{
                .argv = &.{ "date", fmt },
            }) catch null;

            if (result) |r| {
                if (r.term == .exited and r.term.exited == 0) {
                    const trimmed = std.mem.trim(u8, r.stdout, " \n\r\t");
                    if (trimmed.len <= cached_time.len) {
                        @memcpy(cached_time[0..trimmed.len], trimmed);
                        cached_len = trimmed.len;
                        last_minute_of_day = current_minute;
                        time_str = cached_time[0..cached_len];
                    } else {
                        time_str = trimmed;
                    }
                }
            } else {
                // Fallback to native UTC formatting when `date` is unavailable
                const epoch_secs = std.time.epoch.EpochSeconds{ .secs = total_seconds };
                const day_secs = epoch_secs.getDaySeconds();
                const hour = day_secs.getHoursIntoDay();
                const minute = day_secs.getMinutesIntoHour();

                const formatted = if (time_format == .H12)
                    format12h(&cached_time, hour, minute)
                else
                    format24h(&cached_time, hour, minute);
                cached_len = formatted.len;
                last_minute_of_day = current_minute;
                time_str = cached_time[0..cached_len];
            }
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

fn format24h(buf: *[32]u8, hour: u5, minute: u6) []const u8 {
    return std.fmt.bufPrint(buf[0..], "{d:0>2}:{d:0>2} ", .{ hour, minute }) catch unreachable;
}

fn format12h(buf: *[32]u8, hour: u5, minute: u6) []const u8 {
    const is_pm = hour >= 12;
    const display_hour = if (hour == 0) 12 else if (hour > 12) hour - 12 else hour;
    const suffix = if (is_pm) "PM" else "AM";
    return std.fmt.bufPrint(buf[0..], "{d:0>2}:{d:0>2} {s} ", .{ display_hour, minute, suffix }) catch unreachable;
}

test "format24h produces HH:MM " {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("09:05 ", format24h(&buf, 9, 5));
    try std.testing.expectEqualStrings("23:59 ", format24h(&buf, 23, 59));
    try std.testing.expectEqualStrings("00:00 ", format24h(&buf, 0, 0));
}

test "format12h produces HH:MM AM/PM " {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("12:00 AM ", format12h(&buf, 0, 0));
    try std.testing.expectEqualStrings("12:30 PM ", format12h(&buf, 12, 30));
    try std.testing.expectEqualStrings("03:45 PM ", format12h(&buf, 15, 45));
    try std.testing.expectEqualStrings("11:59 PM ", format12h(&buf, 23, 59));
}
