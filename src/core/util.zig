const std = @import("std");

/// Runs a git command and returns stdout on success.
/// Caller owns the returned memory.
pub fn runGitCommand(allocator: std.mem.Allocator, io: std.Io, argv: []const []const u8, cwd: ?[]const u8) ![]u8 {
    const result = try std.process.run(allocator, io, .{
        .argv = argv,
        .cwd = if (cwd) |p| .{ .path = p } else .inherit,
    });
    defer allocator.free(result.stderr);

    if (result.term != .exited or result.term.exited != 0) {
        allocator.free(result.stdout);
        return error.GitError;
    }

    return result.stdout;
}

/// Trims a branch name to max 25 chars, appending "..." if truncated.
/// Caller owns the returned memory.
pub fn trimBranchName(allocator: std.mem.Allocator, branch: []const u8) ![]const u8 {
    if (branch.len <= 25) return try allocator.dupe(u8, branch);
    return try std.fmt.allocPrint(allocator, "{s}...", .{branch[0..25]});
}
