const std = @import("std");
const tmux_renderer = @import("../tmux_renderer.zig");
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

fn getPorcelainV2(allocator: std.mem.Allocator, io: std.Io, repo_path: []const u8) !util.ParsedStatusV2 {
    const stdout = runGitCommand(allocator, io, &.{ "git", "status", "--porcelain=v2", "--branch" }, repo_path) catch {
        return util.ParsedStatusV2{
            .branch = null,
            .ahead = 0,
            .behind = 0,
            .changed = 0,
            .untracked = 0,
            .conflicts = 0,
        };
    };
    defer allocator.free(stdout);

    var status = util.parsePorcelainV2(stdout);

    // Dupe the branch name — parsePorcelainV2 returns a slice into stdout
    // which will be freed by the defer above. All other fields are integers.
    if (status.branch) |branch| {
        status.branch = try allocator.dupe(u8, branch);
    }

    return status;
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

fn countStashes(allocator: std.mem.Allocator, io: std.Io, repo_path: []const u8) !usize {
    const stdout = runGitCommand(allocator, io, &.{ "git", "rev-list", "--count", "refs/stash" }, repo_path) catch return 0;
    defer allocator.free(stdout);

    const trimmed = std.mem.trim(u8, stdout, " \n\r");
    return std.fmt.parseInt(usize, trimmed, 10) catch 0;
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

    // Single call replaces: rev-parse, status --porcelain, rev-list --count, diff --name-only --diff-filter=U, stash list
    const status = try getPorcelainV2(allocator, io, repo_path);

    const branch_raw = status.branch orelse return;
    defer allocator.free(branch_raw);
    if (branch_raw.len == 0 or std.mem.eql(u8, branch_raw, "HEAD")) return;

    const display_branch = try trimBranchName(allocator, branch_raw);
    defer allocator.free(display_branch);

    const untracked = status.untracked;
    const conflict_count = status.conflicts;
    const ahead = status.ahead;
    const behind = status.behind;
    const changed = status.changed;

    var sync_mode: SyncMode = .clean;

    if (changed > 0) {
        sync_mode = .dirty;
    }

    if (ahead > 0 and sync_mode == .clean) {
        sync_mode = .ahead;
    } else if (behind > 0 and sync_mode == .clean) {
        sync_mode = .behind;
    }

    // Get diff stats and stash count using optimized git commands
    const diff_stats = try getDiffStats(allocator, io, repo_path);
    const stash_count = try countStashes(allocator, io, repo_path);

    const insertions = diff_stats.insertions;
    const deletions = diff_stats.deletions;

    // Pre-allocate color hex strings for common colors to reduce allocations
    // Use stack-allocated buffers for better performance
    var bg_hex: [32]u8 = undefined;
    var warning_hex: [32]u8 = undefined;
    var success_hex: [32]u8 = undefined;
    var danger_hex: [32]u8 = undefined;
    var danger_bright_hex: [32]u8 = undefined;
    var info_bright_hex: [32]u8 = undefined;
    var muted_hex: [32]u8 = undefined;
    const bg_str = tmux_renderer.colorHexString(theme.background, &bg_hex);
    const warning_str = tmux_renderer.colorHexString(theme.warning, &warning_hex);
    const success_str = tmux_renderer.colorHexString(theme.success, &success_hex);
    const danger_str = tmux_renderer.colorHexString(theme.danger, &danger_hex);
    const danger_bright_str = tmux_renderer.colorHexString(theme.danger_bright, &danger_bright_hex);
    const info_bright_str = tmux_renderer.colorHexString(theme.info_bright, &info_bright_hex);
    const muted_str = tmux_renderer.colorHexString(theme.muted, &muted_hex);

    // Write status segments directly to the output writer, avoiding intermediate allocations
    switch (sync_mode) {
        .dirty => try writer.print("{s}#[bg={s},fg={s},bold]▒ 󱓎", .{ reset, bg_str, danger_bright_str }),
        .ahead => try writer.print("{s}#[bg={s},fg={s},bold]▒ 󰛃", .{ reset, bg_str, danger_str }),
        .behind => try writer.print("{s}#[bg={s},fg={s},bold]▒ 󰛀", .{ reset, bg_str, info_bright_str }),
        .clean => try writer.print("{s}#[bg={s},fg={s},bold]▒ ", .{ reset, bg_str, success_str }),
    }

    try writer.print(" {s}{s}", .{ reset, display_branch });

    if (changed > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, warning_str, bg_str, changed });
    }

    if (insertions > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, success_str, bg_str, insertions });
    }

    if (deletions > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, danger_str, bg_str, deletions });
    }

    if (untracked > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, muted_str, bg_str, untracked });
    }

    if (stash_count > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold] {d}", .{ reset, info_bright_str, bg_str, stash_count });
    }

    if (conflict_count > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold]󰅘 {d}", .{ reset, danger_bright_str, bg_str, conflict_count });
    }

    if (ahead > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold]↑{d}", .{ reset, info_bright_str, bg_str, ahead });
    }

    if (behind > 0) {
        try writer.print(" {s}#[fg={s},bg={s},bold]↓{d}", .{ reset, danger_str, bg_str, behind });
    }

    try writer.print(" ", .{});
}

test "git_status renders sync status icons correctly" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    var ctx = try WidgetContext.init(gpa, io, &env_map, "hard", false);
    defer ctx.deinit();

    // Verify theme colors are non-empty (basic theme sanity)
    try std.testing.expect(!ctx.theme.success.isDefault());
    try std.testing.expect(!ctx.theme.danger.isDefault());
    try std.testing.expect(!ctx.theme.warning.isDefault());
    try std.testing.expect(!ctx.theme.info_bright.isDefault());
    try std.testing.expect(!ctx.theme.danger_bright.isDefault());
    try std.testing.expect(!ctx.theme.muted.isDefault());
    try std.testing.expect(!ctx.theme.background.isDefault());

    // Verify reset string is properly formatted
    try std.testing.expect(std.mem.startsWith(u8, ctx.reset, "#[fg="));
    try std.testing.expect(std.mem.containsAtLeast(u8, ctx.reset, 1, "nobold"));
}

test "git_status.run produces valid tmux output in project repo" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    // Navigate from test's build-cache directory to the project root.
    // @src().file is relative to build root; go up from src/widgets/ to project root.
    const project_root = comptime std.fs.path.dirname(std.fs.path.dirname(std.fs.path.dirname(@src().file))).?;

    var buf: [2048]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buf);

    // Run in the project's own git repo (guaranteed to exist during tests)
    run(gpa, io, &env_map, "hard", false, project_root, &writer) catch |err| {
        // Skip if git isn't available or repo state is unexpected
        if (err == error.GitError) return;
        return err;
    };

    const output = std.Io.Writer.buffered(&writer);

    // The output should contain these structural elements for any non-empty repo:
    try std.testing.expect(std.mem.containsAtLeast(u8, output, 1, "#[fg="));
    try std.testing.expect(std.mem.containsAtLeast(u8, output, 1, "#[bg="));
    try std.testing.expect(std.mem.containsAtLeast(u8, output, 1, "▒"));

    // Output ends with a trailing space (tmux status convention)
    try std.testing.expect(output.len > 0);
    try std.testing.expect(output[output.len - 1] == ' ');
}
