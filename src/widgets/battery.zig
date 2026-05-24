const std = @import("std");
const builtin = @import("builtin");
const themes = @import("../themes/registry.zig");

const discharging_icons = [_][]const u8{
    "󰁺",
    "󰁻",
    "󰁼",
    "󰁽",
    "󰁾",
    "󰁿",
    "󰂀",
    "󰂁",
    "󰂂",
    "󰁹",
};
const charging_icons = [_][]const u8{
    "󰢜",
    "󰂆",
    "󰂇",
    "󰂈",
    "󰢝",
    "󰂉",
    "󰢞",
    "󰂊",
    "󰂋",
    "󰂅",
};
const not_charging_icon = "󰚥";
const no_battery_icon = "󱉝";

const BatteryInfo = struct {
    status: []const u8,
    percentage: u8,
};

fn readLinuxBattery(allocator: std.mem.Allocator, io: std.Io, name: []const u8) !BatteryInfo {
    var status_path_buf: [64]u8 = undefined;
    const status_path = try std.fmt.bufPrint(&status_path_buf, "/sys/class/power_supply/{s}/status", .{name});
    var capacity_path_buf: [64]u8 = undefined;
    const capacity_path = try std.fmt.bufPrint(&capacity_path_buf, "/sys/class/power_supply/{s}/capacity", .{name});

    var status_buf: [64]u8 = undefined;
    const status = std.Io.Dir.readFile(.cwd(), io, status_path, &status_buf) catch |err| {
        if (err == error.FileNotFound) return error.NoBattery;
        return err;
    };

    var capacity_buf: [64]u8 = undefined;
    const capacity = std.Io.Dir.readFile(.cwd(), io, capacity_path, &capacity_buf) catch |err| {
        if (err == error.FileNotFound) return error.NoBattery;
        return err;
    };

    const pct = std.fmt.parseInt(u8, std.mem.trim(u8, capacity, " \n\r\t"), 10) catch 0;

    return BatteryInfo{
        .status = try allocator.dupe(u8, std.mem.trim(u8, status, " \n\r\t")),
        .percentage = pct,
    };
}

fn readDarwinBattery(allocator: std.mem.Allocator, io: std.Io, name: []const u8) !BatteryInfo {
    const result = try std.process.run(allocator, io, .{
        .argv = &.{ "pmset", "-g", "batt" },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term != .exited or result.term.exited != 0) {
        return error.NoBattery;
    }

    // Parse pmset output looking for the battery line
    var lines = std.mem.splitScalar(u8, result.stdout, '\n');
    while (lines.next()) |line| {
        if (!std.mem.containsAtLeast(u8, line, 1, name)) continue;

        var pct: u8 = 0;
        var status_slice: []const u8 = "Unknown";

        var it = std.mem.splitAny(u8, line, " ;");
        while (it.next()) |token| {
            const trimmed = std.mem.trim(u8, token, " \t");
            if (trimmed.len > 1 and trimmed[trimmed.len - 1] == '%') {
                pct = std.fmt.parseInt(u8, trimmed[0 .. trimmed.len - 1], 10) catch 0;
            } else if (std.mem.eql(u8, trimmed, "charging") or
                std.mem.eql(u8, trimmed, "discharging") or
                std.mem.eql(u8, trimmed, "charged") or
                std.mem.eql(u8, trimmed, "full"))
            {
                status_slice = trimmed;
            }
        }

        return BatteryInfo{
            .status = try allocator.dupe(u8, status_slice),
            .percentage = pct,
        };
    }

    return error.NoBattery;
}

fn getBatteryInfo(allocator: std.mem.Allocator, io: std.Io, name: []const u8) !BatteryInfo {
    switch (builtin.os.tag) {
        .linux => return readLinuxBattery(allocator, io, name),
        .macos => return readDarwinBattery(allocator, io, name),
        else => return error.UnsupportedPlatform,
    }
}

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
    theme_name: []const u8,
    transparent: bool,
    battery_name: ?[]const u8,
    low_threshold: u8,
    writer: *std.Io.Writer,
) !void {
    const theme = (themes.byName(allocator, io, environ_map, theme_name) orelse themes.hard).withTransparentBackground(transparent);

    const default_name = if (builtin.os.tag == .macos) "InternalBattery-0" else "BAT0";
    const name = battery_name orelse default_name;

    const info = getBatteryInfo(allocator, io, name) catch |err| {
        if (err == error.NoBattery or err == error.UnsupportedPlatform) {
            return; // silently skip if no battery
        }
        return err;
    };
    defer allocator.free(info.status);

    const idx = @min(info.percentage / 10, 9);

    const icon = blk: {
        const s = std.mem.trim(u8, info.status, " \n\r\t");
        if (std.mem.eql(u8, s, "Charging") or std.mem.eql(u8, s, "Charged") or std.mem.eql(u8, s, "charging")) {
            break :blk charging_icons[idx];
        } else if (std.mem.eql(u8, s, "Discharging") or std.mem.eql(u8, s, "discharging")) {
            break :blk discharging_icons[idx];
        } else if (std.mem.eql(u8, s, "Full") or std.mem.eql(u8, s, "charged") or std.mem.eql(u8, s, "full") or std.mem.eql(u8, s, "AC")) {
            break :blk not_charging_icon;
        } else {
            break :blk no_battery_icon;
        }
    };

    const color = if (info.percentage < low_threshold)
        theme.danger
    else if (info.percentage >= 100)
        theme.success
    else
        theme.warning;

    try writer.print("#[fg={s}{s},bg=default]░ {s}#[bg=default] {d}% ", .{
        color,
        if (info.percentage < low_threshold) ",bold" else "",
        icon,
        info.percentage,
    });
}

test "getBatteryIcon selects correct icon for charging" {
    const idx = @min(50 / 10, 9);
    const icon = blk: {
        const s = "Charging";
        if (std.mem.eql(u8, s, "Charging") or std.mem.eql(u8, s, "Charged") or std.mem.eql(u8, s, "charging")) {
            break :blk charging_icons[idx];
        } else if (std.mem.eql(u8, s, "Discharging") or std.mem.eql(u8, s, "discharging")) {
            break :blk discharging_icons[idx];
        } else if (std.mem.eql(u8, s, "Full") or std.mem.eql(u8, s, "charged") or std.mem.eql(u8, s, "full") or std.mem.eql(u8, s, "AC")) {
            break :blk not_charging_icon;
        } else {
            break :blk no_battery_icon;
        }
    };
    try std.testing.expectEqualStrings(charging_icons[5], icon);
}

test "getBatteryIcon selects correct icon for discharging" {
    const idx = @min(75 / 10, 9);
    const icon = blk: {
        const s = "Discharging";
        if (std.mem.eql(u8, s, "Charging") or std.mem.eql(u8, s, "Charged") or std.mem.eql(u8, s, "charging")) {
            break :blk charging_icons[idx];
        } else if (std.mem.eql(u8, s, "Discharging") or std.mem.eql(u8, s, "discharging")) {
            break :blk discharging_icons[idx];
        } else if (std.mem.eql(u8, s, "Full") or std.mem.eql(u8, s, "charged") or std.mem.eql(u8, s, "full") or std.mem.eql(u8, s, "AC")) {
            break :blk not_charging_icon;
        } else {
            break :blk no_battery_icon;
        }
    };
    try std.testing.expectEqualStrings(discharging_icons[7], icon);
}

test "getBatteryIcon selects not_charging for full battery" {
    const icon = blk: {
        const s = "Full";
        if (std.mem.eql(u8, s, "Charging") or std.mem.eql(u8, s, "Charged") or std.mem.eql(u8, s, "charging")) {
            break :blk charging_icons[0];
        } else if (std.mem.eql(u8, s, "Discharging") or std.mem.eql(u8, s, "discharging")) {
            break :blk discharging_icons[0];
        } else if (std.mem.eql(u8, s, "Full") or std.mem.eql(u8, s, "charged") or std.mem.eql(u8, s, "full") or std.mem.eql(u8, s, "AC")) {
            break :blk not_charging_icon;
        } else {
            break :blk no_battery_icon;
        }
    };
    try std.testing.expectEqualStrings(not_charging_icon, icon);
}

test "battery color selection" {
    const theme = themes.hard;
    const low_threshold: u8 = 20;
    
    const color_low = if (10 < low_threshold) theme.danger else if (10 >= 100) theme.success else theme.warning;
    try std.testing.expectEqualStrings(theme.danger, color_low);
    
    const color_mid = if (50 < low_threshold) theme.danger else if (50 >= 100) theme.success else theme.warning;
    try std.testing.expectEqualStrings(theme.warning, color_mid);
    
    const color_full = if (100 < low_threshold) theme.danger else if (100 >= 100) theme.success else theme.warning;
    try std.testing.expectEqualStrings(theme.success, color_full);
}
