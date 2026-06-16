const std = @import("std");
const tui = @import("tui");
const flavors = @import("flavors_tmux");
const Theme = flavors.theme.Theme;
const themes = flavors.themes;

fn loadTheme(arena: std.mem.Allocator, io: std.Io, name: []const u8) Theme {
    var env_map = std.process.Environ.Map.init(arena);
    defer env_map.deinit();
    return themes.byName(arena, io, &env_map, name) orelse themes.hard;
}

fn colorToHexBuf(color: tui.Color, buf: *[7]u8) []const u8 {
    return switch (color) {
        .rgb => |c| {
            const hex: u24 = (@as(u24, c.r) << 16) | (@as(u24, c.g) << 8) | @as(u24, c.b);
            return std.fmt.bufPrint(buf, "#{x:0>6}", .{hex}) catch "default";
        },
        .default => "default",
        else => "default",
    };
}

const field_names = [_][]const u8{
    "background", "foreground", "surface", "surface_alt",
    "primary", "primary_bright", "on_primary", "on_primary_bright",
    "success", "success_bright", "danger", "danger_bright",
    "warning", "info", "info_bright", "accent", "accent_bright",
    "emphasis", "muted",
    "forge_github", "forge_gitlab", "forge_codeberg",
};

fn getField(theme: Theme, field_name: []const u8) tui.Color {
    inline for (comptime std.meta.fieldNames(Theme)) |fname| {
        if (std.mem.eql(u8, field_name, fname)) {
            return @field(theme, fname);
        }
    }
    @panic("unknown field");
}

fn generateBashCaseBlock(arena: std.mem.Allocator, io: std.Io) ![]const u8 {
    var list: std.ArrayList(u8) = .empty;

    try list.appendSlice(arena, "    case \"$theme_name\" in\n");

    for (themes.names) |name| {
        const theme = loadTheme(arena, io, name);
        var line_buf: [256]u8 = undefined;
        const line = try std.fmt.bufPrint(&line_buf, "        {s})\n", .{name});
        try list.appendSlice(arena, line);

        for (field_names) |field| {
            var hex_buf: [7]u8 = undefined;
            const hex = colorToHexBuf(getField(theme, field), &hex_buf);
            var entry_buf: [128]u8 = undefined;
            const entry_line = try std.fmt.bufPrint(&entry_buf, "            THEMES[{s}_{s}]=\"{s}\"\n", .{ name, field, hex });
            try list.appendSlice(arena, entry_line);
        }
        try list.appendSlice(arena, "            ;;\n");
    }

    try list.appendSlice(arena, "    esac\n");

    return list.toOwnedSlice(arena);
}

fn generateValidThemesLine(arena: std.mem.Allocator) ![]const u8 {
    var list: std.ArrayList(u8) = .empty;
    try list.appendSlice(arena, "VALID_THEMES=(");
    for (themes.names, 0..) |name, i| {
        if (i > 0) try list.append(arena, ' ');
        var name_buf: [64]u8 = undefined;
        const quoted = try std.fmt.bufPrint(&name_buf, "\"{s}\"", .{name});
        try list.appendSlice(arena, quoted);
    }
    try list.appendSlice(arena, ")\n");
    return list.toOwnedSlice(arena);
}

fn replaceBetweenMarkers(arena: std.mem.Allocator, content: []const u8, begin_marker: []const u8, end_marker: []const u8, replacement: []const u8) ![]const u8 {
    const begin_idx = std.mem.indexOf(u8, content, begin_marker) orelse return error.MarkerNotFound;
    const end_idx = std.mem.indexOfPos(u8, content, begin_idx + begin_marker.len, end_marker) orelse return error.MarkerNotFound;

    var result: std.ArrayList(u8) = .empty;
    try result.appendSlice(arena, content[0 .. begin_idx + begin_marker.len]);
    try result.append(arena, '\n');
    try result.appendSlice(arena, replacement);
    try result.appendSlice(arena, content[end_idx..]);
    return result.toOwnedSlice(arena);
}

pub fn main(init: std.process.Init) void {
    const arena = init.arena.allocator();
    const io = init.io;
    const args = init.minimal.args.toSlice(arena) catch {
        std.process.exit(1);
    };
    if (args.len < 2) {
        std.process.exit(1);
    }

    const project_root = args[1];

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const bash_block = generateBashCaseBlock(arena, io) catch {
        std.process.exit(1);
    };

    const valid_line = generateValidThemesLine(arena) catch {
        std.process.exit(1);
    };

    // Read and update scripts/themes.sh
    const themes_sh_path = std.fmt.allocPrint(arena, "{s}/scripts/themes.sh", .{project_root}) catch {
        std.process.exit(1);
    };
    var themes_sh_buf: [65536]u8 = undefined;
    const themes_sh_content = std.Io.Dir.readFile(.cwd(), io, themes_sh_path, &themes_sh_buf) catch "";
    if (themes_sh_content.len > 0) {
        const updated = replaceBetweenMarkers(arena, themes_sh_content, "# BEGIN_CODEGEN_CASE_BLOCK", "# END_CODEGEN_CASE_BLOCK", bash_block) catch themes_sh_content;
        std.Io.Dir.writeFile(.cwd(), io, .{ .sub_path = themes_sh_path, .data = updated }) catch {};
        _ = stdout_writer.print("Updated {s}\n", .{themes_sh_path}) catch {};
    }

    // Read and update flavors.tmux
    const flavors_path = std.fmt.allocPrint(arena, "{s}/flavors.tmux", .{project_root}) catch {
        std.process.exit(1);
    };
    var flavors_buf: [65536]u8 = undefined;
    const flavors_content = std.Io.Dir.readFile(.cwd(), io, flavors_path, &flavors_buf) catch "";
    if (flavors_content.len > 0) {
        const updated = replaceBetweenMarkers(arena, flavors_content, "# BEGIN_CODEGEN_VALID_THEMES", "# END_CODEGEN_VALID_THEMES", valid_line) catch flavors_content;
        std.Io.Dir.writeFile(.cwd(), io, .{ .sub_path = flavors_path, .data = updated }) catch {};
        _ = stdout_writer.print("Updated {s}\n", .{flavors_path}) catch {};
    }
}
