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
    const stdout = runGitCommand(allocator, io, &.{ "git", "diff", "--numstat" }, repo_path) catch return .{ .changed = 0, .insertions = 0, .deletions = 0 };
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
    const stdout = runGitCommand(allocator, io, &.{ "git", "ls-files", "--other", "--directory", "--exclude-standard" }, repo_path) catch return 0;
    defer allocator.free(stdout);

    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |line| {
        if (line.len > 0) count += 1;
    }
    return count;
}

fn checkNeedPush(allocator: std.mem.Allocator, io: std.Io, repo_path: []const u8) !bool {
    const stdout = runGitCommand(allocator, io, &.{ "git", "log", "@{push}.." }, repo_path) catch return false;
    defer allocator.free(stdout);
    return stdout.len > 0;
}

fn checkNeedPull(allocator: std.mem.Allocator, io: std.Io, repo_path: []const u8, branch: []const u8) !bool {
    // Check if origin/branch exists and differs
    const remote_branch = try std.fmt.allocPrint(allocator, "origin/{s}", .{branch});
    defer allocator.free(remote_branch);

    const merge_base = runGitCommand(allocator, io, &.{ "git", "merge-base", branch, remote_branch }, repo_path) catch return false;
    defer allocator.free(merge_base);

    const local_head = runGitCommand(allocator, io, &.{ "git", "rev-parse", branch }, repo_path) catch return false;
    defer allocator.free(local_head);

    const remote_head = runGitCommand(allocator, io, &.{ "git", "rev-parse", remote_branch }, repo_path) catch return false;
    defer allocator.free(remote_head);

    const local_trim = std.mem.trim(u8, local_head, " \n\r\t");
    const remote_trim = std.mem.trim(u8, remote_head, " \n\r\t");

    return !std.mem.eql(u8, local_trim, remote_trim);
}

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    theme_name: []const u8,
    repo_path: []const u8,
    writer: *std.Io.Writer,
) !void {
    const theme = themes.byName(theme_name) orelse themes.hard;

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

    if (changed_count > 0) {
        const stats = try getDiffStats(allocator, io, repo_path);
        changed = stats.changed;
        insertions = stats.insertions;
        deletions = stats.deletions;
        sync_mode = 1;
    } else {
        // Check push/pull status
        const need_push = try checkNeedPush(allocator, io, repo_path);
        if (need_push) {
            sync_mode = 2;
        } else {
            const need_pull = try checkNeedPull(allocator, io, repo_path, branch);
            if (need_pull) {
                sync_mode = 3;
            }
        }
    }

    const untracked = try countUntracked(allocator, io, repo_path);

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
            reset, theme.surface_alt, theme.background, untracked,
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

    try writer.print("{s} {s}{s}{s}", .{
        remote_status,
        reset,
        display_branch,
        segments.items,
    });
}
