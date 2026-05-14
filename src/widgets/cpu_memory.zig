const std = @import("std");
const builtin = @import("builtin");
const themes = @import("../themes/registry.zig");
const Theme = @import("../core/theme.zig").Theme;

const CpuMemStats = struct {
    cpu_percent: u8,
    mem_percent: u8,
};

fn parseLineValue(content: []const u8, prefix: []const u8) !usize {
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, prefix)) {
            var it = std.mem.splitAny(u8, line, " \t");
            _ = it.next(); // skip prefix
            while (it.next()) |token| {
                const trimmed = std.mem.trim(u8, token, " \t");
                if (trimmed.len > 0) {
                    return std.fmt.parseInt(usize, trimmed, 10) catch continue;
                }
            }
        }
    }
    return 0;
}

fn parseCpuStatLine(line: []const u8) struct { total: usize, idle: usize } {
    var it = std.mem.splitAny(u8, line, " \t");
    var total: usize = 0;
    var idle: usize = 0;
    var field_idx: usize = 0;
    while (it.next()) |token| {
        const trimmed = std.mem.trim(u8, token, " \t");
        if (trimmed.len == 0) continue;
        const val = std.fmt.parseInt(usize, trimmed, 10) catch continue;
        total += val;
        if (field_idx == 3) idle = val; // idle is 4th field (0-indexed: 3)
        if (field_idx == 4) idle += val; // iowait is 5th field, add to idle
        field_idx += 1;
    }
    return .{ .total = total, .idle = idle };
}

fn readLinuxStats(_: std.mem.Allocator, io: std.Io) !CpuMemStats {
    // CPU: take two samples of /proc/stat to calculate instantaneous usage
    var cpu_buf: [4096]u8 = undefined;

    const cpu_content_1 = std.Io.Dir.readFile(.cwd(), io, "/proc/stat", &cpu_buf) catch return CpuMemStats{ .cpu_percent = 0, .mem_percent = 0 };
    var cpu_lines_1 = std.mem.splitScalar(u8, cpu_content_1, '\n');
    const first_line_1 = cpu_lines_1.next() orelse return CpuMemStats{ .cpu_percent = 0, .mem_percent = 0 };
    if (!std.mem.startsWith(u8, first_line_1, "cpu ")) return CpuMemStats{ .cpu_percent = 0, .mem_percent = 0 };
    const sample_1 = parseCpuStatLine(first_line_1[4..]);

    try std.Io.sleep(io, .{ .nanoseconds = 100 * std.time.ns_per_ms }, .real);

    const cpu_content_2 = std.Io.Dir.readFile(.cwd(), io, "/proc/stat", &cpu_buf) catch return CpuMemStats{ .cpu_percent = 0, .mem_percent = 0 };
    var cpu_lines_2 = std.mem.splitScalar(u8, cpu_content_2, '\n');
    const first_line_2 = cpu_lines_2.next() orelse return CpuMemStats{ .cpu_percent = 0, .mem_percent = 0 };
    if (!std.mem.startsWith(u8, first_line_2, "cpu ")) return CpuMemStats{ .cpu_percent = 0, .mem_percent = 0 };
    const sample_2 = parseCpuStatLine(first_line_2[4..]);

    const total_delta = sample_2.total - sample_1.total;
    const idle_delta = sample_2.idle - sample_1.idle;
    const cpu_percent: u8 = if (total_delta > 0) @intCast(@min(100, (total_delta - idle_delta) * 100 / total_delta)) else 0;

    // Memory: read /proc/meminfo
    var mem_buf: [4096]u8 = undefined;
    const mem_content = std.Io.Dir.readFile(.cwd(), io, "/proc/meminfo", &mem_buf) catch return CpuMemStats{ .cpu_percent = cpu_percent, .mem_percent = 0 };

    const mem_total = try parseLineValue(mem_content, "MemTotal:");
    const mem_available = try parseLineValue(mem_content, "MemAvailable:");

    const mem_percent: u8 = if (mem_total > 0) @intCast(@min(100, (mem_total - mem_available) * 100 / mem_total)) else 0;

    return CpuMemStats{ .cpu_percent = cpu_percent, .mem_percent = mem_percent };
}

fn readDarwinStats(allocator: std.mem.Allocator, io: std.Io) !CpuMemStats {
    // CPU: top -l 1 -n 0 | head -n 5
    const top_result = try std.process.run(allocator, io, .{
        .argv = &.{ "top", "-l", "1", "-n", "0" },
    });
    defer allocator.free(top_result.stdout);
    defer allocator.free(top_result.stderr);

    var cpu_percent: u8 = 0;
    if (top_result.term == .exited and top_result.term.exited == 0) {
        var lines = std.mem.splitScalar(u8, top_result.stdout, '\n');
        while (lines.next()) |line| {
            // Look for "CPU usage: 12.34% user, 5.67% sys, 81.99% idle"
            if (std.mem.startsWith(u8, line, "CPU usage:")) {
                var it = std.mem.splitAny(u8, line, " ,%");
                var user_val: f64 = 0;
                var sys_val: f64 = 0;
                var found_user = false;
                var found_sys = false;
                while (it.next()) |token| {
                    const trimmed = std.mem.trim(u8, token, " \t");
                    if (std.mem.eql(u8, trimmed, "user")) {
                        found_user = true;
                    } else if (std.mem.eql(u8, trimmed, "sys")) {
                        found_sys = true;
                    } else if (found_user and user_val == 0) {
                        user_val = std.fmt.parseFloat(f64, trimmed) catch 0;
                        found_user = false;
                    } else if (found_sys and sys_val == 0) {
                        sys_val = std.fmt.parseFloat(f64, trimmed) catch 0;
                        found_sys = false;
                    }
                }
                cpu_percent = @intFromFloat(@min(100.0, user_val + sys_val));
                break;
            }
        }
    }

    // Memory: vm_stat
    const vm_result = try std.process.run(allocator, io, .{
        .argv = &.{ "vm_stat" },
    });
    defer allocator.free(vm_result.stdout);
    defer allocator.free(vm_result.stderr);

    var mem_percent: u8 = 0;
    if (vm_result.term == .exited and vm_result.term.exited == 0) {
        var pages_free: usize = 0;
        var pages_active: usize = 0;
        var pages_inactive: usize = 0;
        var pages_wired: usize = 0;
        var page_size: usize = 4096;

        var lines = std.mem.splitScalar(u8, vm_result.stdout, '\n');
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "Pages free:")) {
                pages_free = parseVmStatValue(line) catch 0;
            } else if (std.mem.startsWith(u8, line, "Pages active:")) {
                pages_active = parseVmStatValue(line) catch 0;
            } else if (std.mem.startsWith(u8, line, "Pages inactive:")) {
                pages_inactive = parseVmStatValue(line) catch 0;
            } else if (std.mem.startsWith(u8, line, "Pages wired down:")) {
                pages_wired = parseVmStatValue(line) catch 0;
            } else if (std.mem.startsWith(u8, line, "page size of")) {
                var it = std.mem.splitScalar(u8, line, ' ');
                while (it.next()) |token| {
                    page_size = std.fmt.parseInt(usize, std.mem.trim(u8, token, " \t."), 10) catch continue;
                    if (page_size > 0) break;
                }
            }
        }

        const total_pages = pages_free + pages_active + pages_inactive + pages_wired;
        const used_pages = pages_active + pages_inactive + pages_wired;
        if (total_pages > 0) {
            mem_percent = @intCast(@min(100, used_pages * 100 / total_pages));
        }
    }

    return CpuMemStats{ .cpu_percent = cpu_percent, .mem_percent = mem_percent };
}

fn parseVmStatValue(line: []const u8) !usize {
    var it = std.mem.splitScalar(u8, line, ' ');
    while (it.next()) |token| {
        const trimmed = std.mem.trim(u8, token, " \t.");
        if (trimmed.len > 0 and std.fmt.parseInt(usize, trimmed, 10)) |val| {
            return val;
        } else |_| {}
    }
    return 0;
}

fn getCpuColor(percent: u8, theme: Theme) []const u8 {
    if (percent >= 80) return theme.danger;
    if (percent >= 50) return theme.warning;
    return theme.success;
}

fn getMemColor(percent: u8, theme: Theme) []const u8 {
    if (percent >= 80) return theme.danger;
    if (percent >= 50) return theme.warning;
    return theme.success;
}

test "parseCpuStatLine calculates total and idle correctly" {
    const result = parseCpuStatLine("  100 50 25 200 10 5 3 2");
    try std.testing.expectEqual(@as(usize, 395), result.total);
    try std.testing.expectEqual(@as(usize, 210), result.idle);
}

test "parseLineValue finds value in content" {
    const content = "MemTotal:    16384000 kB\nMemAvailable: 8192000 kB\n";
    const total = try parseLineValue(content, "MemTotal:");
    try std.testing.expectEqual(@as(usize, 16384000), total);
    const available = try parseLineValue(content, "MemAvailable:");
    try std.testing.expectEqual(@as(usize, 8192000), available);
}

test "parseLineValue returns 0 for missing key" {
    const content = "MemTotal: 1000 kB\n";
    const result = try parseLineValue(content, "MissingKey:");
    try std.testing.expectEqual(@as(usize, 0), result);
}

test "getCpuColor returns correct thresholds" {
    const theme = themes.hard;
    try std.testing.expectEqualStrings(theme.danger, getCpuColor(80, theme));
    try std.testing.expectEqualStrings(theme.danger, getCpuColor(100, theme));
    try std.testing.expectEqualStrings(theme.warning, getCpuColor(50, theme));
    try std.testing.expectEqualStrings(theme.warning, getCpuColor(79, theme));
    try std.testing.expectEqualStrings(theme.success, getCpuColor(49, theme));
    try std.testing.expectEqualStrings(theme.success, getCpuColor(0, theme));
}

test "getMemColor returns correct thresholds" {
    const theme = themes.hard;
    try std.testing.expectEqualStrings(theme.danger, getMemColor(80, theme));
    try std.testing.expectEqualStrings(theme.warning, getMemColor(50, theme));
    try std.testing.expectEqualStrings(theme.success, getMemColor(0, theme));
}

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
    theme_name: []const u8,
    transparent: bool,
    writer: *std.Io.Writer,
) !void {
    const theme = (themes.byName(allocator, io, environ_map, theme_name) orelse themes.hard).withTransparentBackground(transparent);

    const stats = switch (builtin.os.tag) {
        .linux => readLinuxStats(allocator, io) catch CpuMemStats{ .cpu_percent = 0, .mem_percent = 0 },
        .macos => readDarwinStats(allocator, io) catch CpuMemStats{ .cpu_percent = 0, .mem_percent = 0 },
        else => CpuMemStats{ .cpu_percent = 0, .mem_percent = 0 },
    };

    const cpu_color = getCpuColor(stats.cpu_percent, theme);
    const mem_color = getMemColor(stats.mem_percent, theme);

    try writer.print("#[fg={s},bg={s},bold]▒ 󰍛 {d}% #[fg={s},bg={s},bold]󰘚 {d}%", .{
        cpu_color, theme.background, stats.cpu_percent,
        mem_color, theme.background, stats.mem_percent,
    });
}
