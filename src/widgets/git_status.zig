const std = @import("std");
const util = @import("../core/util.zig");
const WidgetContext = @import("../core/widget.zig").WidgetContext;
const runGitCommand = util.runGitCommand;
const trimBranchName = util.trimBranchName;

const SyncMode = enum {
    clean,
    dirty,
    ahead,
    behind,
};

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

fn getStatusInfo(allocator: std.mem.Allocator, io: std.Io, repo_path: []const u8) !util.PorcelainStatus {
    const stdout = runGitCommand(allocator, io, &.{ "git", "status", "--porcelain" }, repo_path) catch return util.PorcelainStatus{ .changed = 0, .untracked = 0 };
    defer allocator.free(stdout);
    return util.parsePorcelain(stdout);
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
    var ctx = try WidgetContext.init(allocator, io, environ_map, theme_name, transparent);
    defer ctx.deinit();
    const theme = ctx.theme;
    const reset = ctx.reset;

    // Get branch name
    const branch_raw = runGitCommand(allocator, io, &.{ "git", "rev-parse", "--abbrev-ref", "HEAD" }, repo_path) catch {
        return; // Not a git repo
    };
    defer allocator.free(branch_raw);

    const branch = std.mem.trim(u8, branch_raw, " \n\r\t");
    if (branch.len == 0 or std.mem.eql(u8, branch, "HEAD")) return;

    const display_branch = try trimBranchName(allocator, branch);
    defer allocator.free(display_branch);

    // Single `git status --porcelain` gives both changed and untracked counts
    const status_info = try getStatusInfo(allocator, io, repo_path);

    var sync_mode: SyncMode = .clean;
    var changed: usize = 0;
    var insertions: usize = 0;
    var deletions: usize = 0;

    var ahead: usize = 0;
    var behind: usize = 0;

    if (status_info.changed > 0) {
        const stats = try getDiffStats(allocator, io, repo_path);
        changed = stats.changed;
        insertions = stats.insertions;
        deletions = stats.deletions;
        sync_mode = .dirty;
    }

    // Always check ahead/behind regardless of dirty state
    const ab = try getAheadBehind(allocator, io, repo_path);
    ahead = ab.ahead;
    behind = ab.behind;
    if (ahead > 0 and sync_mode == .clean) {
        sync_mode = .ahead;
    } else if (behind > 0 and sync_mode == .clean) {
        sync_mode = .behind;
    }

    const untracked = status_info.untracked;
    const stash_count = try countStashes(allocator, io, repo_path);
    const conflict_count = try countConflicts(allocator, io, repo_path);

    // Write status segments directly to the output writer, avoiding intermediate allocations
    switch (sync_mode) {
        .dirty => try writer.print("{s}#[bg={s},fg={s},bold]▒ 󱓎", .{ reset, theme.background, theme.danger_bright }),
        .ahead => try writer.print("{s}#[bg={s},fg={s},bold]▒ 󰛃", .{ reset, theme.background, theme.danger }),
        .behind => try writer.print("{s}#[bg={s},fg={s},bold]▒ 󰛀", .{ reset, theme.background, theme.info_bright }),
        .clean => try writer.print("{s}#[bg={s},fg={s},bold]▒ ", .{ reset, theme.background, theme.success }),
    }

    try writer.print(" {s}{s}", .{ reset, display_branch });

    if (changed > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, theme.warning, theme.background, changed });
    }

    if (insertions > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, theme.success, theme.background, insertions });
    }

    if (deletions > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, theme.danger, theme.background, deletions });
    }

    if (untracked > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, theme.muted, theme.background, untracked });
    }

    if (stash_count > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, theme.info_bright, theme.background, stash_count });
    }

    if (conflict_count > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold]󰅘 {d}", .{ reset, theme.danger_bright, theme.background, conflict_count });
    }

    if (ahead > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold]↑{d}", .{ reset, theme.info_bright, theme.background, ahead });
    }

    if (behind > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold]↓{d}", .{ reset, theme.danger, theme.background, behind });
    }

    try writer.print(" ", .{});
}
