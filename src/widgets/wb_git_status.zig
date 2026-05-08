const std = @import("std");
const themes = @import("../themes.zig");

fn runGitCommand(allocator: std.mem.Allocator, io: std.Io, argv: []const []const u8, cwd: ?[]const u8) ![]u8 {
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

fn getProvider(allocator: std.mem.Allocator, io: std.Io, repo_path: []const u8) !?[]const u8 {
    const stdout = runGitCommand(allocator, io, &.{ "git", "config", "remote.origin.url" }, repo_path) catch return null;
    defer allocator.free(stdout);

    const url = std.mem.trim(u8, stdout, " \n\r\t");
    if (url.len == 0) return null;

    // Parse provider from remote URL
    // ssh:   git@github.com:user/repo.git
    // https: https://github.com/user/repo.git
    if (std.mem.startsWith(u8, url, "git@")) {
        const at_idx = std.mem.indexOf(u8, url, "@") orelse return null;
        const colon_idx = std.mem.indexOf(u8, url[at_idx..], ":") orelse return null;
        return try allocator.dupe(u8, url[at_idx + 1 .. at_idx + colon_idx]);
    } else if (std.mem.startsWith(u8, url, "https://")) {
        const after_proto = url[8..];
        const slash_idx = std.mem.indexOf(u8, after_proto, "/") orelse return null;
        return try allocator.dupe(u8, after_proto[0..slash_idx]);
    }
    return null;
}

fn runGhCommand(allocator: std.mem.Allocator, io: std.Io, argv: []const []const u8, repo_path: []const u8) ![]u8 {
    const result = try std.process.run(allocator, io, .{
        .argv = argv,
        .cwd = .{ .path = repo_path },
    });
    defer allocator.free(result.stderr);

    if (result.term != .exited or result.term.exited != 0) {
        allocator.free(result.stdout);
        return error.GhError;
    }

    return result.stdout;
}

fn countJsonArrayItems(allocator: std.mem.Allocator, json_str: []const u8) !usize {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    if (parsed.value != .array) return 0;
    return parsed.value.array.items.len;
}

fn countJsonArrayItemsWithBugLabel(allocator: std.mem.Allocator, json_str: []const u8) !usize {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    if (parsed.value != .array) return 0;

    var count: usize = 0;
    for (parsed.value.array.items) |item| {
        if (item != .object) continue;
        const labels = item.object.get("labels") orelse continue;
        if (labels != .array) continue;
        for (labels.array.items) |label| {
            if (label != .object) continue;
            const name = label.object.get("name") orelse continue;
            if (name != .string) continue;
            if (std.mem.eql(u8, name.string, "bug")) {
                count += 1;
                break;
            }
        }
    }
    return count;
}

fn countLinesMatching(text: []const u8, prefix: []const u8) usize {
    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, prefix)) count += 1;
    }
    return count;
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
    if (branch.len == 0) return;

    // Get provider
    const provider = try getProvider(allocator, io, repo_path);
    defer if (provider) |p| allocator.free(p);

    if (provider == null) return;

    const provider_str = provider.?;

    var pr_count: usize = 0;
    var review_count: usize = 0;
    var issue_count: usize = 0;
    var bug_count: usize = 0;

    var provider_icon: []const u8 = "";

    if (std.mem.eql(u8, provider_str, "github.com")) {
        provider_icon = " ";

        // PR count: gh pr list --json number --jq 'length'
        const pr_json = runGhCommand(allocator, io, &.{ "gh", "pr", "list", "--json", "number" }, repo_path) catch "";
        defer if (pr_json.len > 0) allocator.free(pr_json);
        pr_count = countJsonArrayItems(allocator, pr_json) catch 0;

        // Review count: gh pr status --json reviewRequests --jq '.needsReview | length'
        // Actually the bash script uses: gh pr status --json reviewRequests --jq '.needsReview | length'
        // But gh pr status doesn't accept --json. Let's use: gh pr list --reviewer @me --json number
        const review_json = runGhCommand(allocator, io, &.{ "gh", "pr", "list", "--reviewer", "@me", "--json", "number" }, repo_path) catch "";
        defer if (review_json.len > 0) allocator.free(review_json);
        review_count = countJsonArrayItems(allocator, review_json) catch 0;

        // Issues assigned to me
        const issue_json = runGhCommand(allocator, io, &.{ "gh", "issue", "list", "--json", "assignees,labels", "--assignee", "@me" }, repo_path) catch "";
        defer if (issue_json.len > 0) allocator.free(issue_json);
        const total_issues = countJsonArrayItems(allocator, issue_json) catch 0;
        const bugs = countJsonArrayItemsWithBugLabel(allocator, issue_json) catch 0;
        bug_count = bugs;
        issue_count = total_issues - bugs;
    } else if (std.mem.eql(u8, provider_str, "gitlab.com")) {
        provider_icon = " ";

        // glab mr list
        const mr_text = runGhCommand(allocator, io, &.{ "glab", "mr", "list" }, repo_path) catch "";
        defer if (mr_text.len > 0) allocator.free(mr_text);
        pr_count = countLinesMatching(mr_text, "!");

        // glab mr list --reviewer=@me
        const review_text = runGhCommand(allocator, io, &.{ "glab", "mr", "list", "--reviewer=@me" }, repo_path) catch "";
        defer if (review_text.len > 0) allocator.free(review_text);
        review_count = countLinesMatching(review_text, "!");

        // glab issue list
        const issue_text = runGhCommand(allocator, io, &.{ "glab", "issue", "list" }, repo_path) catch "";
        defer if (issue_text.len > 0) allocator.free(issue_text);
        issue_count = countLinesMatching(issue_text, "#");
    } else {
        return; // Unsupported provider
    }

    const reset = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},nobold,noitalics,nounderscore,nodim]", .{
        theme.foreground,
        theme.background,
    });
    defer allocator.free(reset);

    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    // Header:  + provider icon
    try result.appendSlice(allocator, "#[fg=");
    try result.appendSlice(allocator, theme.surface_alt);
    try result.appendSlice(allocator, ",bg=");
    try result.appendSlice(allocator, theme.background);
    try result.appendSlice(allocator, ",bold] ");
    try result.appendSlice(allocator, reset);
    try result.appendSlice(allocator, "#[fg=");

    if (std.mem.eql(u8, provider_str, "github.com")) {
        try result.appendSlice(allocator, theme.forge_github);
    } else {
        try result.appendSlice(allocator, theme.forge_gitlab);
    }
    try result.appendSlice(allocator, "]");
    try result.appendSlice(allocator, provider_icon);
    try result.appendSlice(allocator, " ");
    try result.appendSlice(allocator, reset);

    if (pr_count > 0) {
        const seg = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},bold] {s}{d} ", .{
            theme.success, theme.background, reset, pr_count,
        });
        defer allocator.free(seg);
        try result.appendSlice(allocator, seg);
    }

    if (review_count > 0) {
        const seg = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},bold] {s}{d} ", .{
            theme.warning, theme.background, reset, review_count,
        });
        defer allocator.free(seg);
        try result.appendSlice(allocator, seg);
    }

    if (issue_count > 0) {
        const seg = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},bold] {s}{d} ", .{
            theme.success, theme.background, reset, issue_count,
        });
        defer allocator.free(seg);
        try result.appendSlice(allocator, seg);
    }

    if (bug_count > 0) {
        const seg = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},bold] {s}{d} ", .{
            theme.danger, theme.background, reset, bug_count,
        });
        defer allocator.free(seg);
        try result.appendSlice(allocator, seg);
    }

    try writer.print("{s}", .{result.items});
}
