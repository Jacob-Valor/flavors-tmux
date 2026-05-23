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

pub const PorcelainStatus = struct {
    changed: usize,
    untracked: usize,
};

/// Parses `git status --porcelain` or `yadm status --porcelain` output,
/// counting changed (tracked modifications) and untracked files.
/// Untracked files are identified by the `??` prefix.
pub fn parsePorcelain(stdout: []const u8) PorcelainStatus {
    var changed: usize = 0;
    var untracked: usize = 0;

    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |line| {
        if (line.len < 2) continue;
        const first = line[0];
        const second = line[1];
        if (first == '?' and second == '?') {
            untracked += 1;
        } else if (first == 'M' or first == 'A' or first == 'D' or first == 'R' or first == 'C' or first == 'U' or
            second == 'M' or second == 'A' or second == 'D')
        {
            changed += 1;
        }
    }
    return .{ .changed = changed, .untracked = untracked };
}

test "parsePorcelain counts changed and untracked" {
    const output = " M src/main.zig\n?? build.zig\nA  src/new.zig\n?? README.md\n D src/old.zig\n";
    const result = parsePorcelain(output);
    try std.testing.expectEqual(@as(usize, 3), result.changed);
    try std.testing.expectEqual(@as(usize, 2), result.untracked);
}

test "parsePorcelain ignores empty and short lines" {
    const output = "\nM\n ?? file.txt\n\n";
    const result = parsePorcelain(output);
    try std.testing.expectEqual(@as(usize, 0), result.changed);
    try std.testing.expectEqual(@as(usize, 1), result.untracked);
}

test "parsePorcelain returns zero for clean repo" {
    const result = parsePorcelain("");
    try std.testing.expectEqual(@as(usize, 0), result.changed);
    try std.testing.expectEqual(@as(usize, 0), result.untracked);
}
