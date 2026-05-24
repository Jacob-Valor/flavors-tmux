const std = @import("std");
const util = @import("../core/util.zig");
const WidgetContext = @import("../core/widget.zig").WidgetContext;
const theme_loader = @import("../core/theme_loader.zig");

const log = std.log.scoped(.wb_git_status);
const runGitCommand = util.runGitCommand;

const max_cache_bytes = 8192;

fn getRemoteUrl(allocator: std.mem.Allocator, io: std.Io, repo_path: []const u8) !?[]const u8 {
    const remote_stdout = runGitCommand(allocator, io, &.{ "git", "remote" }, repo_path) catch return null;
    defer allocator.free(remote_stdout);

    const remote_name = std.mem.trim(u8, remote_stdout, " \n\r\t");
    if (remote_name.len == 0) return null;

    const first_line = std.mem.indexOf(u8, remote_name, "\n") orelse remote_name.len;
    const first_remote = remote_name[0..first_line];

    var config_key_buf: [256]u8 = undefined;
    const config_key = std.fmt.bufPrint(&config_key_buf, "remote.{s}.url", .{first_remote}) catch return null;

    const url_stdout = runGitCommand(allocator, io, &.{ "git", "config", config_key }, repo_path) catch return null;
    defer allocator.free(url_stdout);

    const url = std.mem.trim(u8, url_stdout, " \n\r\t");
    if (url.len == 0) return null;
    return try allocator.dupe(u8, url);
}

fn providerFromUrl(allocator: std.mem.Allocator, url: []const u8) !?[]const u8 {
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

fn cacheBase(environ_map: *std.process.Environ.Map) []const u8 {
    if (environ_map.get("XDG_CACHE_HOME")) |xdg_cache_home| {
        if (xdg_cache_home.len > 0) return xdg_cache_home;
    }
    return "/tmp";
}

fn getHeadHash(allocator: std.mem.Allocator, io: std.Io, repo_path: []const u8) !?[]const u8 {
    const stdout = runGitCommand(allocator, io, &.{ "git", "rev-parse", "HEAD" }, repo_path) catch return null;
    defer allocator.free(stdout);
    const trimmed = std.mem.trim(u8, stdout, " \n\r\t");
    if (trimmed.len == 0) return null;
    return try allocator.dupe(u8, trimmed);
}

fn cachePath(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
    theme_name: []const u8,
    transparent: bool,
    repo_path: []const u8,
    remote_url: []const u8,
    head_hash: ?[]const u8,
) ![]u8 {
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(theme_name);
    hasher.update("\x00");
    var custom_path_buf: [256]u8 = undefined;
    if (theme_loader.customThemePathBuf(environ_map, theme_name, &custom_path_buf) catch null) |custom_path| {
        if (std.Io.Dir.cwd().statFile(io, custom_path, .{})) |stat| {
            var stat_buf: [64]u8 = undefined;
            const stat_key = std.fmt.bufPrint(&stat_buf, "{d}:{d}", .{ stat.mtime.nanoseconds, stat.size }) catch "custom-theme";
            hasher.update(stat_key);
        } else |_| {}
    }
    hasher.update("\x00");
    hasher.update(if (transparent) "1" else "0");
    hasher.update("\x00");
    hasher.update(repo_path);
    hasher.update("\x00");
    hasher.update(remote_url);
    hasher.update("\x00");
    if (head_hash) |h| hasher.update(h);
    const key = hasher.final();

    const base = cacheBase(environ_map);
    return std.fmt.allocPrint(allocator, "{s}/flavors-tmux-wb-{x}.cache", .{ base, key });
}

fn readFreshCache(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    ttl_seconds: u64,
) !?[]u8 {
    if (ttl_seconds == 0) return null;

    var file = std.Io.Dir.openFileAbsolute(io, path, .{}) catch return null;
    defer file.close(io);

    const stat = file.stat(io) catch return null;
    const now = std.Io.Timestamp.now(io, .real);
    const age_ns = now.nanoseconds - stat.mtime.nanoseconds;
    if (age_ns < 0) return null;

    const ttl_ns: i96 = @as(i96, @intCast(ttl_seconds)) * std.time.ns_per_s;
    if (age_ns > ttl_ns) return null;

    var read_buf: [4096]u8 = undefined;
    var reader = file.reader(io, &read_buf);
    return reader.interface.allocRemaining(allocator, .limited(max_cache_bytes)) catch return null;
}

fn writeCache(io: std.Io, path: []const u8, output: []const u8) void {
    std.Io.Dir.writeFile(.cwd(), io, .{ .sub_path = path, .data = output }) catch |err| {
        log.warn("failed to write forge cache to {s}: {s}", .{ path, @errorName(err) });
    };
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

fn commandWorks(allocator: std.mem.Allocator, io: std.Io, argv: []const []const u8) bool {
    const result = std.process.run(allocator, io, .{ .argv = argv }) catch return false;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    return result.term == .exited and result.term.exited == 0;
}

fn getCodebergToken(allocator: std.mem.Allocator, io: std.Io, environ_map: *std.process.Environ.Map) !?[]u8 {
    if (environ_map.get("FLAVORS_TMUX_CODEBERG_TOKEN")) |token| {
        const trimmed = std.mem.trim(u8, token, " \n\r\t");
        if (trimmed.len > 0) return try allocator.dupe(u8, trimmed);
    }
    if (environ_map.get("CODEBERG_TOKEN")) |token| {
        const trimmed = std.mem.trim(u8, token, " \n\r\t");
        if (trimmed.len > 0) return try allocator.dupe(u8, trimmed);
    }

    const result = std.process.run(allocator, io, .{
        .argv = &.{ "tmux", "show-option", "-gv", "@flavors-tmux_codeberg_token" },
    }) catch return null;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term != .exited or result.term.exited != 0) return null;
    const trimmed = std.mem.trim(u8, result.stdout, " \n\r\t");
    if (trimmed.len == 0) return null;
    return try allocator.dupe(u8, trimmed);
}

fn isValidToken(token: []const u8) bool {
    for (token) |c| {
        if (c < 0x20 or c > 0x7E) return false;
    }
    return true;
}

fn parseCodebergOwnerRepo(allocator: std.mem.Allocator, remote_url: []const u8) !?[]const u8 {
    // Supports git@codeberg.org:owner/repo.git and https://codeberg.org/owner/repo.git
    var start: usize = 0;
    if (std.mem.startsWith(u8, remote_url, "git@codeberg.org:")) {
        start = 17; // len("git@codeberg.org:")
    } else if (std.mem.startsWith(u8, remote_url, "https://codeberg.org/")) {
        start = 21; // len("https://codeberg.org/")
    } else {
        return null;
    }

    var end = remote_url.len;
    if (std.mem.endsWith(u8, remote_url, ".git")) {
        end -= 4;
    }

    if (start >= end) return null;
    return try allocator.dupe(u8, remote_url[start..end]);
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

fn renderUncached(
    allocator: std.mem.Allocator,
    io: std.Io,
    theme_name: []const u8,
    transparent: bool,
    repo_path: []const u8,
    provider_str: []const u8,
    environ_map: *std.process.Environ.Map,
) ![]u8 {
    // Build output into an ArrayList, avoiding per-segment heap allocations
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    var ctx = WidgetContext.init(allocator, io, environ_map, theme_name, transparent) catch {
        return result.toOwnedSlice(allocator);
    };
    defer ctx.deinit();
    const theme = ctx.theme;
    const reset = ctx.reset;

    // Get branch name
    const branch_raw = runGitCommand(allocator, io, &.{ "git", "rev-parse", "--abbrev-ref", "HEAD" }, repo_path) catch {
        return result.toOwnedSlice(allocator);
    };
    defer allocator.free(branch_raw);

    const branch = std.mem.trim(u8, branch_raw, " \n\r\t");
    if (branch.len == 0) return result.toOwnedSlice(allocator);

    var pr_count: usize = 0;
    var review_count: usize = 0;
    var issue_count: usize = 0;
    var bug_count: usize = 0;

    var provider_icon: []const u8 = "";

    if (std.mem.eql(u8, provider_str, "github.com")) {
        if (!commandWorks(allocator, io, &.{ "gh", "--version" })) return result.toOwnedSlice(allocator);
        provider_icon = " ";

        // PR count: gh pr list --json number --limit 100 --jq 'length'
        const pr_json = runGhCommand(allocator, io, &.{ "gh", "pr", "list", "--json", "number", "--limit", "100" }, repo_path) catch "";
        defer if (pr_json.len > 0) allocator.free(pr_json);
        pr_count = countJsonArrayItems(allocator, pr_json) catch 0;

        // Review count: gh pr list --reviewer @me --json number --limit 100
        const review_json = runGhCommand(allocator, io, &.{ "gh", "pr", "list", "--reviewer", "@me", "--json", "number", "--limit", "100" }, repo_path) catch "";
        defer if (review_json.len > 0) allocator.free(review_json);
        review_count = countJsonArrayItems(allocator, review_json) catch 0;

        // Issues assigned to me
        const issue_json = runGhCommand(allocator, io, &.{ "gh", "issue", "list", "--json", "assignees,labels", "--assignee", "@me", "--limit", "100" }, repo_path) catch "";
        defer if (issue_json.len > 0) allocator.free(issue_json);
        const total_issues = countJsonArrayItems(allocator, issue_json) catch 0;
        const bugs = countJsonArrayItemsWithBugLabel(allocator, issue_json) catch 0;
        bug_count = bugs;
        issue_count = total_issues - bugs;
    } else if (std.mem.eql(u8, provider_str, "gitlab.com")) {
        if (!commandWorks(allocator, io, &.{ "glab", "--version" })) return result.toOwnedSlice(allocator);
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
    } else if (std.mem.eql(u8, provider_str, "codeberg.org")) {
        if (!commandWorks(allocator, io, &.{ "curl", "--version" })) return result.toOwnedSlice(allocator);

        const token = try getCodebergToken(allocator, io, environ_map);
        defer if (token) |t| allocator.free(t);
        if (token == null) return result.toOwnedSlice(allocator);
        if (!isValidToken(token.?)) return result.toOwnedSlice(allocator);

        provider_icon = " ";

        // Get remote URL to parse owner/repo
        const remote_url_opt = try getRemoteUrl(allocator, io, repo_path);
        defer if (remote_url_opt) |url| allocator.free(url);
        if (remote_url_opt == null) return result.toOwnedSlice(allocator);

        const owner_repo = try parseCodebergOwnerRepo(allocator, remote_url_opt.?);
        defer if (owner_repo) |or_| allocator.free(or_);
        if (owner_repo == null) return result.toOwnedSlice(allocator);

        const api_base = "https://codeberg.org/api/v1";
        const auth_header = try std.fmt.allocPrint(allocator, "Authorization: token {s}", .{token.?});
        defer allocator.free(auth_header);

        // PR count
        const pr_url = try std.fmt.allocPrint(allocator, "{s}/repos/{s}/pulls?state=open&limit=100", .{ api_base, owner_repo.? });
        defer allocator.free(pr_url);
        const pr_json = runGhCommand(allocator, io, &.{ "curl", "-sS", "--fail", "--max-time", "5", "-H", auth_header, "-L", pr_url }, repo_path) catch "";
        defer if (pr_json.len > 0) allocator.free(pr_json);
        pr_count = countJsonArrayItems(allocator, pr_json) catch 0;

        // Issue count (excludes PRs in Gitea API when using /issues endpoint)
        const issue_url = try std.fmt.allocPrint(allocator, "{s}/repos/{s}/issues?state=open&limit=100", .{ api_base, owner_repo.? });
        defer allocator.free(issue_url);
        const issue_json = runGhCommand(allocator, io, &.{ "curl", "-sS", "--fail", "--max-time", "5", "-H", auth_header, "-L", issue_url }, repo_path) catch "";
        defer if (issue_json.len > 0) allocator.free(issue_json);
        issue_count = countJsonArrayItems(allocator, issue_json) catch 0;
    } else {
        return result.toOwnedSlice(allocator); // Unsupported provider
    }

    // Write segments directly via appendSlice — no per-segment heap allocations
    // Header:  + provider icon
    try result.appendSlice(allocator, "#[fg=");
    try result.appendSlice(allocator, theme.muted);
    try result.appendSlice(allocator, ",bg=");
    try result.appendSlice(allocator, theme.background);
    try result.appendSlice(allocator, ",bold] ");
    try result.appendSlice(allocator, reset);
    try result.appendSlice(allocator, "#[fg=");

    if (std.mem.eql(u8, provider_str, "github.com")) {
        try result.appendSlice(allocator, theme.forge_github);
    } else if (std.mem.eql(u8, provider_str, "codeberg.org")) {
        try result.appendSlice(allocator, theme.forge_codeberg);
    } else {
        try result.appendSlice(allocator, theme.forge_gitlab);
    }
    try result.appendSlice(allocator, "]");
    try result.appendSlice(allocator, provider_icon);
    try result.appendSlice(allocator, " ");
    try result.appendSlice(allocator, reset);

    var num_buf: [20]u8 = undefined;

    if (pr_count > 0) {
        try result.appendSlice(allocator, "#[fg=");
        try result.appendSlice(allocator, theme.success);
        try result.appendSlice(allocator, ",bg=");
        try result.appendSlice(allocator, theme.background);
        try result.appendSlice(allocator, ",bold] ");
        try result.appendSlice(allocator, reset);
        try result.appendSlice(allocator, " ");
        const num = try std.fmt.bufPrint(&num_buf, "{d}", .{pr_count});
        try result.appendSlice(allocator, num);
        try result.appendSlice(allocator, " ");
    }

    if (review_count > 0) {
        try result.appendSlice(allocator, "#[fg=");
        try result.appendSlice(allocator, theme.warning);
        try result.appendSlice(allocator, ",bg=");
        try result.appendSlice(allocator, theme.background);
        try result.appendSlice(allocator, ",bold] ");
        try result.appendSlice(allocator, reset);
        try result.appendSlice(allocator, " ");
        const num = try std.fmt.bufPrint(&num_buf, "{d}", .{review_count});
        try result.appendSlice(allocator, num);
        try result.appendSlice(allocator, " ");
    }

    if (issue_count > 0) {
        try result.appendSlice(allocator, "#[fg=");
        try result.appendSlice(allocator, theme.success);
        try result.appendSlice(allocator, ",bg=");
        try result.appendSlice(allocator, theme.background);
        try result.appendSlice(allocator, ",bold] ");
        try result.appendSlice(allocator, reset);
        try result.appendSlice(allocator, " ");
        const num = try std.fmt.bufPrint(&num_buf, "{d}", .{issue_count});
        try result.appendSlice(allocator, num);
        try result.appendSlice(allocator, " ");
    }

    if (bug_count > 0) {
        try result.appendSlice(allocator, "#[fg=");
        try result.appendSlice(allocator, theme.danger);
        try result.appendSlice(allocator, ",bg=");
        try result.appendSlice(allocator, theme.background);
        try result.appendSlice(allocator, ",bold] ");
        try result.appendSlice(allocator, reset);
        try result.appendSlice(allocator, " ");
        const num = try std.fmt.bufPrint(&num_buf, "{d}", .{bug_count});
        try result.appendSlice(allocator, num);
        try result.appendSlice(allocator, " ");
    }

    return result.toOwnedSlice(allocator);
}

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
    theme_name: []const u8,
    transparent: bool,
    repo_path: []const u8,
    cache_ttl: u64,
    writer: *std.Io.Writer,
) !void {
    const remote_url = try getRemoteUrl(allocator, io, repo_path);
    defer if (remote_url) |url| allocator.free(url);
    if (remote_url == null) return;

    const provider = try providerFromUrl(allocator, remote_url.?);
    defer if (provider) |p| allocator.free(p);
    if (provider == null) return;

    const head_hash = try getHeadHash(allocator, io, repo_path);
    defer if (head_hash) |h| allocator.free(h);

    const path = try cachePath(allocator, io, environ_map, theme_name, transparent, repo_path, remote_url.?, head_hash);
    defer allocator.free(path);

    const cached = try readFreshCache(allocator, io, path, cache_ttl);
    if (cached) |output| {
        defer allocator.free(output);
        try writer.print("{s}", .{output});
        return;
    }

    const output = try renderUncached(allocator, io, theme_name, transparent, repo_path, provider.?, environ_map);
    defer allocator.free(output);

    if (output.len > 0) writeCache(io, path, output);
    try writer.print("{s}", .{output});
}

test "providerFromUrl extracts host from SSH and HTTPS URLs" {
    const gpa = std.testing.allocator;

    const ssh = try providerFromUrl(gpa, "git@github.com:user/repo.git");
    defer if (ssh) |s| gpa.free(s);
    try std.testing.expectEqualStrings("github.com", ssh.?);

    const https = try providerFromUrl(gpa, "https://gitlab.com/user/repo");
    defer if (https) |s| gpa.free(s);
    try std.testing.expectEqualStrings("gitlab.com", https.?);

    const bad = try providerFromUrl(gpa, "ftp://example.com/repo");
    try std.testing.expect(bad == null);
}

test "parseCodebergOwnerRepo extracts owner/repo from Codeberg URLs" {
    const gpa = std.testing.allocator;

    const ssh = try parseCodebergOwnerRepo(gpa, "git@codeberg.org:owner/repo.git");
    defer if (ssh) |s| gpa.free(s);
    try std.testing.expectEqualStrings("owner/repo", ssh.?);

    const https = try parseCodebergOwnerRepo(gpa, "https://codeberg.org/owner/repo");
    defer if (https) |s| gpa.free(s);
    try std.testing.expectEqualStrings("owner/repo", https.?);

    const bad = try parseCodebergOwnerRepo(gpa, "https://github.com/owner/repo");
    try std.testing.expect(bad == null);
}

test "countLinesMatching counts lines with prefix" {
    const text = "!123\n#456\n!789\n\nabc\n";
    try std.testing.expectEqual(@as(usize, 2), countLinesMatching(text, "!"));
    try std.testing.expectEqual(@as(usize, 1), countLinesMatching(text, "#"));
    try std.testing.expectEqual(@as(usize, 0), countLinesMatching(text, "x"));
}

test "isValidToken rejects control characters" {
    try std.testing.expect(isValidToken("abc123"));
    try std.testing.expect(isValidToken("token_with-special.chars"));
    try std.testing.expect(!isValidToken("bad\ntoken"));
    try std.testing.expect(!isValidToken("bad\rtoken"));
    try std.testing.expect(!isValidToken("\x00null"));
    try std.testing.expect(!isValidToken("del\x7F"));
}
