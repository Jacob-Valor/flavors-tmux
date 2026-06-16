const std = @import("std");
const tui = @import("tui");

const Color = tui.Color;
const Style = tui.Style;

/// Write the tmux format string prefix for a given Style.
/// Produces a combined segment like `#[fg=#rrggbb,bg=#rrggbb,bold]`
/// or `#[fg=colourN]` to match the project's Bash convention.
pub fn writeStyle(style: Style, writer: anytype) !void {
    var buf: [256]u8 = undefined;
    var pos: usize = 0;

    // Foreground
    switch (style.fg) {
        .default => {},
        .rgb => |c| {
            const s = try std.fmt.bufPrint(buf[pos..], "fg=#{x:0>2}{x:0>2}{x:0>2}", .{ c.r, c.g, c.b });
            pos += s.len;
        },
        .basic => |b| {
            const s = try std.fmt.bufPrint(buf[pos..], "fg=colour{d}", .{@intFromEnum(b)});
            pos += s.len;
        },
        .palette => |p| {
            const s = try std.fmt.bufPrint(buf[pos..], "fg=colour{d}", .{p});
            pos += s.len;
        },
    }

    // Background
    switch (style.bg) {
        .default => {},
        .rgb => |c| {
            if (pos > 0) { buf[pos] = ','; pos += 1; }
            const s = try std.fmt.bufPrint(buf[pos..], "bg=#{x:0>2}{x:0>2}{x:0>2}", .{ c.r, c.g, c.b });
            pos += s.len;
        },
        .basic => |b| {
            if (pos > 0) { buf[pos] = ','; pos += 1; }
            const s = try std.fmt.bufPrint(buf[pos..], "bg=colour{d}", .{@intFromEnum(b)});
            pos += s.len;
        },
        .palette => |p| {
            if (pos > 0) { buf[pos] = ','; pos += 1; }
            const s = try std.fmt.bufPrint(buf[pos..], "bg=colour{d}", .{p});
            pos += s.len;
        },
    }

    // Attributes (all use tmux attribute names within the same #[...] bracket)
    if (style.attrs.bold) {
        if (pos > 0) { buf[pos] = ','; pos += 1; }
        const s = try std.fmt.bufPrint(buf[pos..], "bold", .{});
        pos += s.len;
    }
    if (style.attrs.dim) {
        if (pos > 0) { buf[pos] = ','; pos += 1; }
        const s = try std.fmt.bufPrint(buf[pos..], "dim", .{});
        pos += s.len;
    }
    if (style.attrs.italic) {
        if (pos > 0) { buf[pos] = ','; pos += 1; }
        const s = try std.fmt.bufPrint(buf[pos..], "italic", .{});
        pos += s.len;
    }
    if (style.attrs.underline) {
        if (pos > 0) { buf[pos] = ','; pos += 1; }
        const s = try std.fmt.bufPrint(buf[pos..], "underscore", .{});
        pos += s.len;
    }
    if (style.attrs.blink) {
        if (pos > 0) { buf[pos] = ','; pos += 1; }
        const s = try std.fmt.bufPrint(buf[pos..], "blink", .{});
        pos += s.len;
    }
    if (style.attrs.reverse) {
        if (pos > 0) { buf[pos] = ','; pos += 1; }
        const s = try std.fmt.bufPrint(buf[pos..], "reverse", .{});
        pos += s.len;
    }
    if (style.attrs.strikethrough) {
        if (pos > 0) { buf[pos] = ','; pos += 1; }
        const s = try std.fmt.bufPrint(buf[pos..], "strikethrough", .{});
        pos += s.len;
    }
    if (style.attrs.hidden) {
        if (pos > 0) { buf[pos] = ','; pos += 1; }
        const s = try std.fmt.bufPrint(buf[pos..], "hidden", .{});
        pos += s.len;
    }

    // Write the combined segment if anything was set
    if (pos > 0) {
        try writer.print("#[{s}]", .{ buf[0..pos] });
    }
}

/// Write a "reset" style that sets fg, bg and turns off all attributes.
pub fn writeReset(fg: Color, bg: Color, writer: anytype) !void {
    try writer.print("#[fg=", .{});
    switch (fg) {
        .default => try writer.writeAll("default"),
        .rgb => |c| try writer.print("#{x:0>2}{x:0>2}{x:0>2}", .{ c.r, c.g, c.b }),
        .basic => |b| try writer.print("colour{d}", .{@intFromEnum(b)}),
        .palette => |p| try writer.print("colour{d}", .{p}),
    }
    try writer.print(",bg=", .{});
    switch (bg) {
        .default => try writer.writeAll("default"),
        .rgb => |c| try writer.print("#{x:0>2}{x:0>2}{x:0>2}", .{ c.r, c.g, c.b }),
        .basic => |b| try writer.print("colour{d}", .{@intFromEnum(b)}),
        .palette => |p| try writer.print("colour{d}", .{p}),
    }
    try writer.writeAll(",nobold,noitalics,nounderscore,nodim]");
}

/// Format a Color as a hex string for CLI output (e.g., `#1b1b1b`).
/// Returns .default as "default". Caller provides output buffer.
/// Optimized to reduce allocations and improve performance.
pub fn colorHexString(color: Color, buf: []u8) []const u8 {
    switch (color) {
        .default => return "default",
        .rgb => |c| return writeRgbHex(c, buf),
        .basic => |b| writeColour(buf, @intFromEnum(b)),
        .palette => |p| writeColour(buf, p),
    }
}

fn writeRgbHex(c: Color.RGB, buf: []u8) []const u8 {
    const buf_len = buf.len;
    if (buf_len < 7) return "default";

    var pos: usize = 0;
    buf[pos] = '#'; pos += 1;

    const hex_chars = "0123456789abcdef";
    buf[pos] = hex_chars[c.r >> 4]; pos += 1;
    buf[pos] = hex_chars[c.r & 0xF]; pos += 1;
    buf[pos] = hex_chars[c.g >> 4]; pos += 1;
    buf[pos] = hex_chars[c.g & 0xF]; pos += 1;
    buf[pos] = hex_chars[c.b >> 4]; pos += 1;
    buf[pos] = hex_chars[c.b & 0xF]; pos += 1;

    return buf[0..pos];
}

fn writeColour(buf: []u8, color_num: usize) []const u8 {
    const buf_len = buf.len;
    const prefix = "colour";
    const prefix_len = prefix.len;
    if (buf_len < prefix_len + 1) return "default";

    @memcpy(buf[0..prefix_len], prefix);

    var temp_buf: [16]u8 = undefined;
    const num_str = std.fmt.bufPrint(&temp_buf, "{d}", .{color_num}) catch return "default";
    const num_len = num_str.len;

    if (prefix_len + num_len > buf_len) return "default";
    @memcpy(buf[prefix_len .. prefix_len + num_len], num_str);
    return buf[0 .. prefix_len + num_len];
}

// --- Tests ---

test "writeReset produces correct tmux format" {
    var buf: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try writeReset(Color.hex(0x1b1b1b), Color.hex(0xfbf1c7), stream.writer());
    const output = stream.getWritten();
    try std.testing.expect(std.mem.startsWith(u8, output, "#[fg=#1b1b1b,bg=#fbf1c7"));
    try std.testing.expect(std.mem.containsAtLeast(u8, output, 1, "nobold"));
    try std.testing.expect(std.mem.containsAtLeast(u8, output, 1, "noitalics"));
}

test "writeStyle handles bold+italic+fg in combined format" {
    var buf: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const style = Style.default.setFg(Color.hex(0x3fb950)).bold().italic();
    try writeStyle(style, stream.writer());
    const output = stream.getWritten();
    try std.testing.expectEqualStrings("#[fg=#3fb950,bold,italic]", output);
}

test "writeStyle handles fg+bg+dim" {
    var buf: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const style = Style.default.setFg(Color.hex(0xfbf1c7)).setBg(Color.hex(0x1b1b1b)).dim();
    try writeStyle(style, stream.writer());
    const output = stream.getWritten();
    try std.testing.expectEqualStrings("#[fg=#fbf1c7,bg=#1b1b1b,dim]", output);
}

test "writeStyle empty style writes nothing" {
    var buf: [4]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const style = Style.default;
    try writeStyle(style, stream.writer());
    const output = stream.getWritten();
    try std.testing.expectEqualStrings("", output);
}

test "colorHexString formats correctly" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("#1b1b1b", colorHexString(Color.hex(0x1b1b1b), &buf));
    try std.testing.expectEqualStrings("default", colorHexString(Color.default, &buf));
}
