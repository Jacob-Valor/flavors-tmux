const std = @import("std");

pub const Args = struct {
    command: []const u8 = "",
    positional: std.ArrayList([]const u8),
    theme: []const u8 = "hard",
    time_format: []const u8 = "24H",
    battery_name: ?[]const u8 = null,
    low_threshold: u8 = 20,
    cache_ttl: u64 = 300,

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
            args.time_format = raw_args[i];
        } else if (std.mem.eql(u8, arg, "--name")) {
            i += 1;
            if (i >= raw_args.len) return error.MissingValue;
            args.battery_name = raw_args[i];
        } else if (std.mem.eql(u8, arg, "--low-threshold")) {
            i += 1;
            if (i >= raw_args.len) return error.MissingValue;
            args.low_threshold = std.fmt.parseInt(u8, raw_args[i], 10) catch return error.InvalidNumber;
        } else if (std.mem.eql(u8, arg, "--cache-ttl")) {
            i += 1;
            if (i >= raw_args.len) return error.MissingValue;
            args.cache_ttl = std.fmt.parseInt(u64, raw_args[i], 10) catch return error.InvalidNumber;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            return error.UnknownOption;
        } else {
            try args.positional.append(allocator, arg);
        }
    }

    return args;
}
