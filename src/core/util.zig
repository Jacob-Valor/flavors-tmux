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

/// Parses `git status --porcelain` or `yadm status --porcelain` output.
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

/// Consolidated result from `git status --porcelain=v2 --branch`.
pub const ParsedStatusV2 = struct {
    branch: ?[]const u8,
    ahead: usize,
    behind: usize,
    changed: usize,
    untracked: usize,
    conflicts: usize,
};

/// Parses `git status --porcelain=v2 --branch` output.
///
/// Extracts branch name, ahead/behind counts, changed file count,
/// untracked file count, and merge conflict count.
pub fn parsePorcelainV2(stdout: []const u8) ParsedStatusV2 {
    var branch: ?[]const u8 = null;
    var ahead: usize = 0;
    var behind: usize = 0;
    var changed: usize = 0;
    var untracked: usize = 0;
    var conflicts: usize = 0;

    var line_start: usize = 0;
    var line_end: usize = 0;
    while (line_end < stdout.len) {
        while (line_end < stdout.len and stdout[line_end] != '\n') {
            line_end += 1;
        }

        if (line_end > line_start) {
            const line = stdout[line_start..line_end];

            if (line[0] == '#') {
                if (std.mem.startsWith(u8, line, "# branch.head ")) {
                    const name = line["# branch.head ".len..];
                    if (!std.mem.eql(u8, name, "(detached)")) {
                        branch = name;
                    }
                } else if (std.mem.startsWith(u8, line, "# branch.ab ")) {
                    const rest = line["# branch.ab ".len..];
                    var i: usize = 0;
                    while (i < rest.len) {
                        if (rest[i] == '+') {
                            i += 1;
                            const num_start = i;
                            while (i < rest.len and std.ascii.isDigit(rest[i])) {
                                i += 1;
                            }
                            if (i > num_start) {
                                const num_str = rest[num_start..i];
                                ahead = std.fmt.parseInt(usize, num_str, 10) catch 0;
                            }
                        } else if (rest[i] == '-') {
                            i += 1;
                            const num_start = i;
                            while (i < rest.len and std.ascii.isDigit(rest[i])) {
                                i += 1;
                            }
                            if (i > num_start) {
                                const num_str = rest[num_start..i];
                                behind = std.fmt.parseInt(usize, num_str, 10) catch 0;
                            }
                        } else {
                            i += 1;
                        }
                    }
                }
            } else {
                switch (line[0]) {
                    '1', '2' => {
                        if (line.len >= 4) {
                            const xy = line[2..4];
                            if (!std.mem.eql(u8, xy, "..")) {
                                changed += 1;
                            }
                        }
                    },
                    '?' => untracked += 1,
                    'u' => conflicts += 1,
                    '!' => {}, // ignored — not counted
                    else => {},
                }
            }
        }

        line_start = line_end + 1;
        line_end = line_start;
    }

    return .{
        .branch = branch,
        .ahead = ahead,
        .behind = behind,
        .changed = changed,
        .untracked = untracked,
        .conflicts = conflicts,
    };
}

test "parsePorcelainV2 extracts branch and counts" {
    const output =
        \\# branch.oid deadbeef
        \\# branch.head main
        \\# branch.upstream origin/main
        \\# branch.ab +2 -1
        \\1 .M N... 100644 100644 100644 abc def src/main.zig
        \\1 M. N... 100644 100644 100644 abc def src/lib.zig
        \\? new_file.txt
        \\? another.txt
        \\u UU N... 100644 100644 100644 abc def conflict.zig
        \\
    ;
    const result = parsePorcelainV2(output);
    try std.testing.expectEqualStrings("main", result.branch.?);
    try std.testing.expectEqual(@as(usize, 2), result.ahead);
    try std.testing.expectEqual(@as(usize, 1), result.behind);
    try std.testing.expectEqual(@as(usize, 2), result.changed);
    try std.testing.expectEqual(@as(usize, 2), result.untracked);
    try std.testing.expectEqual(@as(usize, 1), result.conflicts);
}

test "parsePorcelainV2 handles detached HEAD" {
    const output =
        \\# branch.head (detached)
        \\# branch.ab +0 -0
        \\
    ;
    const result = parsePorcelainV2(output);
    try std.testing.expect(result.branch == null);
}

test "parsePorcelainV2 handles clean repo" {
    const output =
        \\# branch.head dev
        \\# branch.ab +0 -0
        \\
    ;
    const result = parsePorcelainV2(output);
    try std.testing.expectEqualStrings("dev", result.branch.?);
    try std.testing.expectEqual(@as(usize, 0), result.ahead);
    try std.testing.expectEqual(@as(usize, 0), result.changed);
    try std.testing.expectEqual(@as(usize, 0), result.untracked);
    try std.testing.expectEqual(@as(usize, 0), result.insertions);
    try std.testing.expectEqual(@as(usize, 0), result.deletions);
    try std.testing.expectEqual(@as(usize, 0), result.stashes);
}

test "parsePorcelainV2 extracts diff stats and stash count" {
    const output =
        \\# branch.head main
        \\# branch.ab +0 -0
        \\# branch.stash 5
        \\1 .M N... 100644 100644 100644 abc def src/main.zig
        \\1 M. N... 100644 100644 100644 abc def src/lib.zig
        \\
    ;
    const result = parsePorcelainV2(output);
    try std.testing.expectEqualStrings("main", result.branch.?);
    try std.testing.expectEqual(@as(usize, 0), result.ahead);
    try std.testing.expectEqual(@as(usize, 0), result.behind);
    try std.testing.expectEqual(@as(usize, 2), result.changed);
    try std.testing.expectEqual(@as(usize, 0), result.untracked);
    try std.testing.expectEqual(@as(usize, 0), result.conflicts);
    try std.testing.expectEqual(@as(usize, 100), result.insertions);
    try std.testing.expectEqual(@as(usize, 100), result.deletions);
    try std.testing.expectEqual(@as(usize, 5), result.stashes);
}

test "parsePorcelainV2 handles empty stash count" {
    const output =
        \\# branch.head main
        \\# branch.ab +0 -0
        \\
    ;
    const result = parsePorcelainV2(output);
    try std.testing.expectEqualStrings("main", result.branch.?);
    try std.testing.expectEqual(@as(usize, 0), result.ahead);
    try std.testing.expectEqual(@as(usize, 0), result.behind);
    try std.testing.expectEqual(@as(usize, 0), result.changed);
    try std.testing.expectEqual(@as(usize, 0), result.untracked);
    try std.testing.expectEqual(@as(usize, 0), result.conflicts);
    try std.testing.expectEqual(@as(usize, 0), result.insertions);
    try std.testing.expectEqual(@as(usize, 0), result.deletions);
    try std.testing.expectEqual(@as(usize, 0), result.stashes);
}

test "parsePorcelainV2 ignores .. no-change entries" {
    const output =
        \\# branch.head main
        \\# branch.ab +0 -0
        \\1 .. N... 100644 100644 100644 abc def unchanged.zig
        \\1 .M N... 100644 100644 100644 abc def changed.zig
        \\
    ;
    const result = parsePorcelainV2(output);
    try std.testing.expectEqual(@as(usize, 1), result.changed);
}
