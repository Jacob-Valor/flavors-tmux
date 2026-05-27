const std = @import("std");

pub const TimeFormat = enum {
    H12,
    H24,
    hide,

    pub fn fromString(s: []const u8) ?TimeFormat {
        if (std.mem.eql(u8, s, "12H")) return .H12;
        if (std.mem.eql(u8, s, "24H")) return .H24;
        if (std.mem.eql(u8, s, "hide")) return .hide;
        return null;
    }

    pub fn toString(self: TimeFormat) []const u8 {
        return switch (self) {
            .H12 => "12H",
            .H24 => "24H",
            .hide => "hide",
        };
    }
};

pub const Args = struct {
    command: []const u8 = "",
    positional: std.ArrayList([]const u8),
    theme: []const u8 = "hard",
    time_format: TimeFormat = .H24,
    battery_name: ?[]const u8 = null,
    low_threshold: u8 = 20,
    cache_ttl: u64 = 300,
    transparent: bool = false,
    pane_path: ?[]const u8 = null,

    pub fn init() Args {
        return .{ .positional = .empty };
    }

    pub fn deinit(self: *Args, allocator: std.mem.Allocator) void {
        self.positional.deinit(allocator);
    }
};

pub fn parseArgs(allocator: std.mem.Allocator, raw_args: []const []const u8) !Args {
    var args = Args.init();
    errdefer args.deinit(allocator);

    if (raw_args.len == 0) return error.Usage;
    args.command = raw_args[0];

    var i: usize = 1;
    while (i < raw_args.len) : (i += 1) {
        const arg = raw_args[i];
        if (std.mem.eql(u8, arg, "--theme")) {
            i += 1;
            if (i >= raw_args.len) return error.MissingValue;
            args.theme = raw_args[i];
        } else if (std.mem.eql(u8, arg, "--format")) {
            i += 1;
            if (i >= raw_args.len) return error.MissingValue;
            const format_str = raw_args[i];
            args.time_format = TimeFormat.fromString(format_str) orelse return error.InvalidFormat;
        } else if (std.mem.eql(u8, arg, "--name")) {
            i += 1;
            if (i >= raw_args.len) return error.MissingValue;
            args.battery_name = raw_args[i];
        } else if (std.mem.eql(u8, arg, "--low-threshold")) {
            i += 1;
            if (i >= raw_args.len) return error.MissingValue;
            args.low_threshold = std.fmt.parseInt(u8, raw_args[i], 10) catch return error.InvalidNumber;
        } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--cache-ttl")) {
            i += 1;
            if (i >= raw_args.len) return error.MissingValue;
            args.cache_ttl = std.fmt.parseInt(u64, raw_args[i], 10) catch return error.InvalidNumber;
        } else if (std.mem.eql(u8, arg, "--transparent")) {
            args.transparent = true;
        } else if (std.mem.eql(u8, arg, "--pane-path")) {
            i += 1;
            if (i >= raw_args.len) return error.MissingValue;
            args.pane_path = raw_args[i];
        } else if (std.mem.startsWith(u8, arg, "-")) {
            return error.UnknownOption;
        } else {
            try args.positional.append(allocator, arg);
        }
    }

    return args;
}

test "TimeFormat fromString valid values" {
    try std.testing.expectEqual(TimeFormat.H12, TimeFormat.fromString("12H").?);
    try std.testing.expectEqual(TimeFormat.H24, TimeFormat.fromString("24H").?);
    try std.testing.expectEqual(TimeFormat.hide, TimeFormat.fromString("hide").?);
    try std.testing.expect(TimeFormat.fromString("invalid") == null);
    try std.testing.expect(TimeFormat.fromString("") == null);
}

test "TimeFormat toString" {
    try std.testing.expectEqualStrings("12H", TimeFormat.H12.toString());
    try std.testing.expectEqualStrings("24H", TimeFormat.H24.toString());
    try std.testing.expectEqualStrings("hide", TimeFormat.hide.toString());
}

test "parseArgs validates time format" {
    const gpa = std.testing.allocator;
    
    const valid_args = &.{ "datetime", "--format", "12H" };
    const args = try parseArgs(gpa, valid_args);
    defer args.deinit(gpa);
    try std.testing.expectEqual(TimeFormat.H12, args.time_format);
    
    const invalid_args = &.{ "datetime", "--format", "invalid" };
    try std.testing.expectError(error.InvalidFormat, parseArgs(gpa, invalid_args));
}

test "parseArgs default time format is 24H" {
    const gpa = std.testing.allocator;
    const raw_args = &.{ "datetime" };
    const args = try parseArgs(gpa, raw_args);
    defer args.deinit(gpa);
    try std.testing.expectEqual(TimeFormat.H24, args.time_format);
}
