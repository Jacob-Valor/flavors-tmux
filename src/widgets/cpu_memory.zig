const std = @import("std");
const builtin = @import("builtin");
const tui = @import("tui");
const Color = tui.Color;
const tmux_renderer = @import("../tmux_renderer.zig");
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

fn readLinuxStats(allocator: std.mem.Allocator, io: std.Io) !CpuMemStats {
    const cache_path = try std.fmt.allocPrint(allocator, "/tmp/flavors-tmux-cpu-cache", .{});
    defer allocator.free(cache_path);

    // Read current /proc/stat sample
    var cpu_buf: [4096]u8 = undefined;
    const cpu_content = std.Io.Dir.readFile(.cwd(), io, "/proc/stat", &cpu_buf) catch return CpuMemStats{ .cpu_percent = 0, .mem_percent = 0 };
    var cpu_lines = std.mem.splitScalar(u8, cpu_content, '\n');
    const first_line = cpu_lines.next() orelse return CpuMemStats{ .cpu_percent = 0, .mem_percent = 0 };
    if (!std.mem.startsWith(u8, first_line, "cpu ")) return CpuMemStats{ .cpu_percent = 0, .mem_percent = 0 };
    const current = parseCpuStatLine(first_line[4..]);
    const now_ns = std.Io.Timestamp.now(io, .real).nanoseconds;

    // Try to read previous sample from cache
    var cpu_percent: u8 = 0;
    const cache_content = std.Io.Dir.readFile(.cwd(), io, cache_path, &cpu_buf) catch null;
    if (cache_content) |content| {
        // Format: "timestamp_ns total idle"
        var it = std.mem.splitScalar(u8, content, ' ');
        const prev_ns_str = it.next() orelse "";
        const prev_total_str = it.next() orelse "";
        const prev_idle_str = it.next() orelse "";

        const prev_ns = std.fmt.parseInt(i128, std.mem.trim(u8, prev_ns_str, " \n\r\t"), 10) catch 0;
        const prev_total = std.fmt.parseInt(usize, std.mem.trim(u8, prev_total_str, " \n\r\t"), 10) catch 0;
        const prev_idle = std.fmt.parseInt(usize, std.mem.trim(u8, prev_idle_str, " \n\r\t"), 10) catch 0;

        // Only use cached sample if it's recent (<5s old)
        const age_ns = now_ns - prev_ns;
        if (prev_ns > 0 and age_ns > 0 and age_ns < 5 * std.time.ns_per_s) {
            const total_delta = std.math.sub(usize, current.total, prev_total) catch 0;
            const idle_delta = std.math.sub(usize, current.idle, prev_idle) catch 0;
            if (total_delta > 0) {
                cpu_percent = @intCast(@min(100, (total_delta -| idle_delta) * 100 / total_delta));
            }
        }
    }

    // Write current sample for next invocation
    var cache_line_buf: [128]u8 = undefined;
    const cache_line = try std.fmt.bufPrint(&cache_line_buf, "{d} {d} {d}\n", .{ now_ns, current.total, current.idle });
    std.Io.Dir.writeFile(.cwd(), io, .{ .sub_path = cache_path, .data = cache_line }) catch {};

    // Memory: read /proc/meminfo
    var mem_buf: [4096]u8 = undefined;
    const mem_content = std.Io.Dir.readFile(.cwd(), io, "/proc/meminfo", &mem_buf) catch return CpuMemStats{ .cpu_percent = cpu_percent, .mem_percent = 0 };

    const mem_total = try parseLineValue(mem_content, "MemTotal:");
    const mem_available = blk: {
        const val = parseLineValue(mem_content, "MemAvailable:") catch 0;
        if (val > 0) break :blk val;
        break :blk parseLineValue(mem_content, "MemFree:") catch 0;
    };

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
            }
        }

        // Note: vm_stat reports page counts; the percentage is a ratio of counts,
        // so page size cancels out and does not need to be parsed.
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

fn getCpuColor(percent: u8, theme: Theme) Color {
    if (percent >= 80) return theme.danger;
    if (percent >= 50) return theme.warning;
    return theme.success;
}

fn getMemColor(percent: u8, theme: Theme) Color {
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
    try std.testing.expect(std.meta.eql(theme.danger, getCpuColor(80, theme)));
    try std.testing.expect(std.meta.eql(theme.danger, getCpuColor(100, theme)));
    try std.testing.expect(std.meta.eql(theme.warning, getCpuColor(50, theme)));
    try std.testing.expect(std.meta.eql(theme.warning, getCpuColor(79, theme)));
    try std.testing.expect(std.meta.eql(theme.success, getCpuColor(49, theme)));
    try std.testing.expect(std.meta.eql(theme.success, getCpuColor(0, theme)));
}

test "getMemColor returns correct thresholds" {
    const theme = themes.hard;
    try std.testing.expect(std.meta.eql(theme.danger, getMemColor(80, theme)));
    try std.testing.expect(std.meta.eql(theme.warning, getMemColor(50, theme)));
    try std.testing.expect(std.meta.eql(theme.success, getMemColor(0, theme)));
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
    var bg_buf: [32]u8 = undefined;

    try writer.print("#[fg={s},bg={s},bold]▒ 󰍛 {d}% #[fg={s},bg={s},bold]󰘚 {d}%", .{
        tmux_renderer.colorHexString(cpu_color, &bg_buf),
        tmux_renderer.colorHexString(theme.background, &bg_buf),
        stats.cpu_percent,
        tmux_renderer.colorHexString(mem_color, &bg_buf),
        tmux_renderer.colorHexString(theme.background, &bg_buf),
        stats.mem_percent,
    });
}
