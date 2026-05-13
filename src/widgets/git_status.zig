const std = @import("std");
const themes = @import("../themes/registry.zig");
const util = @import("../core/util.zig");
const runGitCommand = util.runGitCommand;
const trimBranchName = util.trimBranchName;

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

const GitStatusInfo = struct {
    branch: []const u8,
    ahead: usize,
    behind: usize,
    changed: usize,
    untracked: usize,
    conflict: usize,
};

fn parseGitStatusV2(allocator: std.mem.Allocator, output: []const u8) !GitStatusInfo {
    var info = GitStatusInfo{
        .branch = try allocator.dupe(u8, ""),
        .ahead = 0,
        .behind = 0,
        .changed = 0,
        .untracked = 0,
        .conflict = 0,
    };
    errdefer allocator.free(info.branch);

    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "# branch.head ")) {
            const name = line["# branch.head ".len..];
            if (name.len > 0) {
                allocator.free(info.branch);
                info.branch = try allocator.dupe(u8, name);
            }
        } else if (std.mem.startsWith(u8, line, "# branch.ab +")) {
            // Format: # branch.ab +<ahead> -<behind>
            var it = std.mem.splitScalar(u8, line, ' ');
            _ = it.next(); // #
            _ = it.next(); // branch.ab
            const ahead_str = it.next() orelse continue;
            const behind_str = it.next() orelse continue;
            if (ahead_str.len > 1 and ahead_str[0] == '+') {
                info.ahead = std.fmt.parseInt(usize, ahead_str[1..], 10) catch 0;
            }
            if (behind_str.len > 1 and behind_str[0] == '-') {
                info.behind = std.fmt.parseInt(usize, behind_str[1..], 10) catch 0;
            }
        } else if (std.mem.startsWith(u8, line, "1 ")) {
            // Ordinary change: 1 <XY> ...
            if (line.len > 3) {
                const xy = line[2..4];
                if (!std.mem.eql(u8, xy, "..")) {
                    info.changed += 1;
                }
            }
        } else if (std.mem.startsWith(u8, line, "2 ")) {
            // Renamed or copied
            info.changed += 1;
        } else if (std.mem.startsWith(u8, line, "u ")) {
            // Unmerged (conflict)
            info.conflict += 1;
        } else if (std.mem.startsWith(u8, line, "? ")) {
            // Untracked
            info.untracked += 1;
        }
    }

    return info;
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

    // Single batched git status call for branch, changes, ahead/behind, untracked, conflicts
    const status_output = runGitCommand(allocator, io, &.{
        "git", "status", "--porcelain=v2", "--branch", "--untracked-files=all",
    }, repo_path) catch {
        return; // Not a git repo
    };
    defer allocator.free(status_output);

    const info = try parseGitStatusV2(allocator, status_output);
    defer allocator.free(info.branch);

    const branch = std.mem.trim(u8, info.branch, " \n\r\t");
    if (branch.len == 0 or std.mem.eql(u8, branch, "HEAD") or std.mem.eql(u8, branch, "(detached)")) return;

    const display_branch = try trimBranchName(allocator, branch);
    defer allocator.free(display_branch);

    // Diff stats (only if there are changes)
    var sync_mode: u2 = 0;
    var changed: usize = info.changed;
    var insertions: usize = 0;
    var deletions: usize = 0;
    const ahead: usize = info.ahead;
    const behind: usize = info.behind;

    if (changed > 0) {
        const stats = try getDiffStats(allocator, io, repo_path);
        changed = stats.changed;
        insertions = stats.insertions;
        deletions = stats.deletions;
        sync_mode = 1;
    } else {
        if (ahead > 0) {
            sync_mode = 2;
        } else if (behind > 0) {
            sync_mode = 3;
        }
    }

    // Stash count
    const stash = try countStashes(allocator, io, repo_path);

    const reset = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},nobold,noitalics,nounderscore,nodim]", .{
        theme.foreground,
        theme.background,
    });
    defer allocator.free(reset);

    // Branch name with padding for better visual spacing
    try writer.print("{s} #[fg={s},bg={s},bold] {s} ", .{ reset, theme.danger, theme.background, display_branch });

    // Changed files
    if (info.changed > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, theme.warning, theme.background, changed });
    }

    // Insertions
    if (insertions > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, theme.success, theme.background, insertions });
    }

    // Deletions
    if (deletions > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, theme.danger, theme.background, deletions });
    }

    // Untracked
    if (info.untracked > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, theme.muted, theme.background, info.untracked });
    }

    // Stash
    if (stash > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, theme.info_bright, theme.background, stash });
    }

    // Conflicts
    if (info.conflict > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold]󰅘 {d}", .{ reset, theme.danger_bright, theme.background, info.conflict });
    }

    // Sync status
    const remote_status = switch (sync_mode) {
        0 => try std.fmt.allocPrint(allocator, "{s}#[bg={s},fg={s},bold]▒ ", .{ reset, theme.background, theme.success }),
        1 => try std.fmt.allocPrint(allocator, "{s}#[bg={s},fg={s},bold]▒ 󱓎", .{ reset, theme.background, theme.danger_bright }),
        2 => try std.fmt.allocPrint(allocator, "{s}#[bg={s},fg={s},bold]▒ 󰛃", .{ reset, theme.background, theme.danger }),
        3 => try std.fmt.allocPrint(allocator, "{s}#[bg={s},fg={s},bold]▒ 󰛀", .{ reset, theme.background, theme.info_bright }),
    };
    defer allocator.free(remote_status);
    try writer.print(" {s}", .{remote_status});
}
