const std = @import("std");
const themes = @import("../themes/registry.zig");
const util = @import("../core/util.zig");
const runGitCommand = util.runGitCommand;
const trimBranchName = util.trimBranchName;

fn countChangedFiles(allocator: std.mem.Allocator, io: std.Io, repo_path: []const u8) !usize {
    const stdout = runGitCommand(allocator, io, &.{ "git", "status", "--porcelain" }, repo_path) catch return 0;
    defer allocator.free(stdout);

    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |line| {
        if (line.len < 2) continue;
        // Match lines starting with M,  M, A, D, R, C, U
        const first = line[0];
        const second = line[1];
        if (first == 'M' or first == 'A' or first == 'D' or first == 'R' or first == 'C' or first == 'U' or
            second == 'M' or second == 'A' or second == 'D')
        {
            count += 1;
        }
    }
    return count;
}

fn getDiffStats(allocator: std.mem.Allocator, io: std.Io, repo_path: []const u8) !struct { changed: usize, insertions: usize, deletions: usize } {
    const stdout = runGitCommand(allocator, io, &.{ "git", "diff", "--numstat", "HEAD" }, repo_path) catch return .{ .changed = 0, .insertions = 0, .deletions = 0 };
    defer allocator.free(stdout);

    var changed: usize = 0;
    var insertions: usize = 0;
    var deletions: usize = 0;

    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |line| {
        var it = std.mem.splitScalar(u8, line, '\t');
        const ins_str = it.next() orelse continue;
        const del_str = it.next() orelse continue;
        if (ins_str.len == 0 or del_str.len == 0) continue;

        const ins = std.fmt.parseInt(usize, ins_str, 10) catch 0;
        const del = std.fmt.parseInt(usize, del_str, 10) catch 0;
        changed += 1;
        insertions += ins;
        deletions += del;
    }

    return .{ .changed = changed, .insertions = insertions, .deletions = deletions };
}

fn countUntracked(allocator: std.mem.Allocator, io: std.Io, repo_path: []const u8) !usize {
    const stdout = runGitCommand(allocator, io, &.{ "git", "ls-files", "--other", "--exclude-standard" }, repo_path) catch return 0;
    defer allocator.free(stdout);

    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |line| {
        if (line.len > 0) count += 1;
    }
    return count;
}

fn countStashes(allocator: std.mem.Allocator, io: std.Io, repo_path: []const u8) !usize {
    const stdout = runGitCommand(allocator, io, &.{ "git", "stash", "list" }, repo_path) catch return 0;
    defer allocator.free(stdout);

    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |line| {
        if (line.len > 0) count += 1;
    }
    return count;
}

fn countConflicts(allocator: std.mem.Allocator, io: std.Io, repo_path: []const u8) !usize {
    const stdout = runGitCommand(allocator, io, &.{ "git", "diff", "--name-only", "--diff-filter=U" }, repo_path) catch return 0;
    defer allocator.free(stdout);

    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |line| {
        if (line.len > 0) count += 1;
    }
    return count;
}

fn getAheadBehind(allocator: std.mem.Allocator, io: std.Io, repo_path: []const u8) !struct { ahead: usize, behind: usize } {
    const stdout = runGitCommand(allocator, io, &.{ "git", "rev-list", "--left-right", "--count", "HEAD...@{upstream}" }, repo_path) catch return .{ .ahead = 0, .behind = 0 };
    defer allocator.free(stdout);

    var it = std.mem.splitScalar(u8, std.mem.trim(u8, stdout, " \n\r\t"), '\t');
    const ahead_str = it.next() orelse return .{ .ahead = 0, .behind = 0 };
    const behind_str = it.next() orelse return .{ .ahead = 0, .behind = 0 };

    const ahead = std.fmt.parseInt(usize, ahead_str, 10) catch 0;
    const behind = std.fmt.parseInt(usize, behind_str, 10) catch 0;
    return .{ .ahead = ahead, .behind = behind };
}

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
    theme_name: []const u8,
    transparent: bool,
    repo_path: []const u8,
    writer: *std.Io.Writer,
) !void {
    const theme = (themes.byName(allocator, io, environ_map, theme_name) orelse themes.hard).withTransparentBackground(transparent);

    // Get branch name
    const branch_raw = runGitCommand(allocator, io, &.{ "git", "rev-parse", "--abbrev-ref", "HEAD" }, repo_path) catch {
        return; // Not a git repo
    };
    defer allocator.free(branch_raw);

    const branch = std.mem.trim(u8, branch_raw, " \n\r\t");
    if (branch.len == 0 or std.mem.eql(u8, branch, "HEAD")) return;

    const display_branch = try trimBranchName(allocator, branch);
    defer allocator.free(display_branch);

    // Check for changes
    const changed_count = try countChangedFiles(allocator, io, repo_path);

    var sync_mode: u2 = 0;
    var changed: usize = 0;
    var insertions: usize = 0;
    var deletions: usize = 0;

    var ahead: usize = 0;
    var behind: usize = 0;

    if (changed_count > 0) {
        const stats = try getDiffStats(allocator, io, repo_path);
        changed = stats.changed;
        insertions = stats.insertions;
        deletions = stats.deletions;
        sync_mode = 1;
    } else {
        // Check push/pull status with numeric counts
        const ab = try getAheadBehind(allocator, io, repo_path);
        ahead = ab.ahead;
        behind = ab.behind;
        if (ahead > 0) {
            sync_mode = 2;
        } else if (behind > 0) {
            sync_mode = 3;
        }
    }

    const untracked = try countUntracked(allocator, io, repo_path);
    const stash_count = try countStashes(allocator, io, repo_path);
    const conflict_count = try countConflicts(allocator, io, repo_path);

    const reset = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},nobold,noitalics,nounderscore,nodim]", .{
        theme.foreground,
        theme.background,
    });
    defer allocator.free(reset);

    // Build status segments
    var segments: std.ArrayList(u8) = .empty;
    defer segments.deinit(allocator);

    if (changed > 0) {
        const seg = try std.fmt.allocPrint(allocator, " {s}#[fg={s},bg={s},bold] {d}", .{
            reset, theme.warning, theme.background, changed,
        });
        defer allocator.free(seg);
        try segments.appendSlice(allocator, seg);
    }

    if (insertions > 0) {
        const seg = try std.fmt.allocPrint(allocator, " {s}#[fg={s},bg={s},bold] {d}", .{
            reset, theme.success, theme.background, insertions,
        });
        defer allocator.free(seg);
        try segments.appendSlice(allocator, seg);
    }

    if (deletions > 0) {
        const seg = try std.fmt.allocPrint(allocator, " {s}#[fg={s},bg={s},bold] {d}", .{
            reset, theme.danger, theme.background, deletions,
        });
        defer allocator.free(seg);
        try segments.appendSlice(allocator, seg);
    }

    if (untracked > 0) {
        const seg = try std.fmt.allocPrint(allocator, " {s}#[fg={s},bg={s},bold] {d}", .{
            reset, theme.muted, theme.background, untracked,
        });
        defer allocator.free(seg);
        try segments.appendSlice(allocator, seg);
    }

    if (stash_count > 0) {
        const seg = try std.fmt.allocPrint(allocator, " {s}#[fg={s},bg={s},bold] {d}", .{
            reset, theme.info_bright, theme.background, stash_count,
        });
        defer allocator.free(seg);
        try segments.appendSlice(allocator, seg);
    }

    if (conflict_count > 0) {
        const seg = try std.fmt.allocPrint(allocator, " {s}#[fg={s},bg={s},bold]󰅘 {d}", .{
            reset, theme.danger_bright, theme.background, conflict_count,
        });
        defer allocator.free(seg);
        try segments.appendSlice(allocator, seg);
    }

    if (ahead > 0) {
        const seg = try std.fmt.allocPrint(allocator, " {s}#[fg={s},bg={s},bold]↑{d}", .{
            reset, theme.info_bright, theme.background, ahead,
        });
        defer allocator.free(seg);
        try segments.appendSlice(allocator, seg);
    }

    if (behind > 0) {
        const seg = try std.fmt.allocPrint(allocator, " {s}#[fg={s},bg={s},bold]↓{d}", .{
            reset, theme.danger, theme.background, behind,
        });
        defer allocator.free(seg);
        try segments.appendSlice(allocator, seg);
    }

    const remote_status = switch (sync_mode) {
        1 => try std.fmt.allocPrint(allocator, "{s}#[bg={s},fg={s},bold]▒ 󱓎", .{ reset, theme.background, theme.danger_bright }),
        2 => try std.fmt.allocPrint(allocator, "{s}#[bg={s},fg={s},bold]▒ 󰛃", .{ reset, theme.background, theme.danger }),
        3 => try std.fmt.allocPrint(allocator, "{s}#[bg={s},fg={s},bold]▒ 󰛀", .{ reset, theme.background, theme.info_bright }),
        else => try std.fmt.allocPrint(allocator, "{s}#[bg={s},fg={s},bold]▒ ", .{ reset, theme.background, theme.success }),
    };
    defer allocator.free(remote_status);

    try writer.print("{s} {s}{s}{s} ", .{
        remote_status,
        reset,
        display_branch,
        segments.items,
    });
}
