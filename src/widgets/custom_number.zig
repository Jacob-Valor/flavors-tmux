const std = @import("std");

const formats = std.StaticStringMap([]const u8).initComptime(.{
    .{ "arabic", "0123456789" },
    .{ "fsquare", "󰎡󰎤󰎧󰎪󰎭󰎱󰎳󰎶󰎹󰎼" },
    .{ "hsquare", "󰎣󰎦󰎩󰎬󰎮󰎰󰎵󰎸󰎻󰎾" },
    .{ "dsquare", "󰎢󰎥󰎨󰎫󰎲󰎯󰎴󰎷󰎺󰎽" },
    .{ "super", "⁰¹²³⁴⁵⁶⁷⁸⁹" },
    .{ "sub", "₀₁₂₃₄₅₆₇₈₉" },
    .{ "earabic", "٠١٢٣٤٥٦٧٨٩" },
});

fn comptimeSplitGlyphs(comptime map: []const u8) [10][]const u8 {
    comptime var glyphs: [10][]const u8 = undefined;
    var glyph_count: usize = 0;
    var i: usize = 0;
    while (i < map.len and glyph_count < 10) {
        const len = std.unicode.utf8ByteSequenceLength(map[i]) catch @compileError("invalid UTF-8 in glyph map");
        glyphs[glyph_count] = map[i .. i + len];
        glyph_count += 1;
        i += len;
    }
    return glyphs;
}

const glyph_cache = std.StaticStringMap([10][]const u8).initComptime(.{
    .{ "arabic", comptimeSplitGlyphs("0123456789") },
    .{ "fsquare", comptimeSplitGlyphs("󰎡󰎤󰎧󰎪󰎭󰎱󰎳󰎶󰎹󰎼") },
    .{ "hsquare", comptimeSplitGlyphs("󰎣󰎦󰎩󰎬󰎮󰎰󰎵󰎸󰎻󰎾") },
    .{ "dsquare", comptimeSplitGlyphs("󰎢󰎥󰎨󰎫󰎲󰎯󰎴󰎷󰎺󰎽") },
    .{ "super", comptimeSplitGlyphs("⁰¹²³⁴⁵⁶⁷⁸⁹") },
    .{ "sub", comptimeSplitGlyphs("₀₁₂₃₄₅₆₇₈₉") },
    .{ "earabic", comptimeSplitGlyphs("٠١٢٣٤٥٦٧٨٩") },
});

/// Formats an ID string using the given style. Supported styles:
/// - hide: returns empty string
/// - arabic, fsquare, hsquare, dsquare, super, sub, earabic
/// Each digit is mapped to its corresponding glyph, followed by a space.
pub fn formatNumber(allocator: std.mem.Allocator, id: []const u8, style: []const u8) ![]u8 {
    if (std.mem.eql(u8, style, "hide")) {
        return allocator.dupe(u8, "");
    }

    const glyphs = glyph_cache.get(style) orelse return error.InvalidFormat;

    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    for (id) |char| {
        if (char < '0' or char > '9') continue;
        const idx = char - '0';
        if (idx < glyphs.len) {
            try result.appendSlice(allocator, glyphs[idx]);
            try result.append(allocator, ' ');
        }
    }

    return result.toOwnedSlice(allocator);
}

pub fn run(allocator: std.mem.Allocator, args: []const []const u8, writer: *std.Io.Writer) !void {
    if (args.len < 2) {
        return error.Usage;
    }
    const id = args[0];
    const style = args[1];

    const formatted = try formatNumber(allocator, id, style);
    defer allocator.free(formatted);

    try writer.print("{s}", .{formatted});
}

test "formatNumber arabic" {
    const gpa = std.testing.allocator;
    const result = try formatNumber(gpa, "42", "arabic");
    defer gpa.free(result);
    try std.testing.expectEqualStrings("4 2 ", result);
}

test "formatNumber hide" {
    const gpa = std.testing.allocator;
    const result = try formatNumber(gpa, "123", "hide");
    defer gpa.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "formatNumber invalid format" {
    const gpa = std.testing.allocator;
    try std.testing.expectError(error.InvalidFormat, formatNumber(gpa, "1", "nope"));
}
