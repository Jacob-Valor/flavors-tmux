const std = @import("std");
const themes = @import("../themes/registry.zig");
const Theme = @import("theme.zig").Theme;

/// Shared context for all widgets that handles common operations:
/// - Theme resolution (built-in or custom)
/// - Transparent background handling
/// - Reset string generation
/// - Color threshold helpers
pub const WidgetContext = struct {
    theme: Theme,
    reset: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        environ_map: *std.process.Environ.Map,
        theme_name: []const u8,
        transparent: bool,
    ) !WidgetContext {
        const theme = (themes.byName(allocator, io, environ_map, theme_name) orelse themes.hard).withTransparentBackground(transparent);
        const reset = try std.fmt.allocPrint(allocator, "#[fg={s},bg={s},nobold,noitalics,nounderscore,nodim]", .{
            theme.foreground,
            theme.background,
        });

        return WidgetContext{
            .theme = theme,
            .reset = reset,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *WidgetContext) void {
        self.allocator.free(self.reset);
    }

    /// Returns danger for >=80%, warning for >=50%, success otherwise
    pub fn thresholdColor(self: WidgetContext, percent: u8) []const u8 {
        if (percent >= 80) return self.theme.danger;
        if (percent >= 50) return self.theme.warning;
        return self.theme.success;
    }

    /// Returns danger for low battery, success for full, warning otherwise
    pub fn batteryColor(self: WidgetContext, percentage: u8, low_threshold: u8) []const u8 {
        if (percentage < low_threshold) return self.theme.danger;
        if (percentage >= 100) return self.theme.success;
        return self.theme.warning;
    }

    /// Format a status segment with the given color and icon
    pub fn formatSegment(
        self: WidgetContext,
        color: []const u8,
        icon: []const u8,
        value: usize,
    ) ![]const u8 {
        return std.fmt.allocPrint(self.allocator, " {s}#[fg={s},bg={s},bold]{s} {d}", .{
            self.reset, color, self.theme.background, icon, value,
        });
    }
};

test "WidgetContext thresholdColor" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    var ctx = try WidgetContext.init(gpa, io, &env_map, "hard", false);
    defer ctx.deinit();

    try std.testing.expectEqualStrings(ctx.theme.danger, ctx.thresholdColor(80));
    try std.testing.expectEqualStrings(ctx.theme.danger, ctx.thresholdColor(100));
    try std.testing.expectEqualStrings(ctx.theme.warning, ctx.thresholdColor(50));
    try std.testing.expectEqualStrings(ctx.theme.warning, ctx.thresholdColor(79));
    try std.testing.expectEqualStrings(ctx.theme.success, ctx.thresholdColor(49));
    try std.testing.expectEqualStrings(ctx.theme.success, ctx.thresholdColor(0));
}

test "WidgetContext batteryColor" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    var ctx = try WidgetContext.init(gpa, io, &env_map, "hard", false);
    defer ctx.deinit();

    try std.testing.expectEqualStrings(ctx.theme.danger, ctx.batteryColor(10, 20));
    try std.testing.expectEqualStrings(ctx.theme.warning, ctx.batteryColor(50, 20));
    try std.testing.expectEqualStrings(ctx.theme.success, ctx.batteryColor(100, 20));
}

test "WidgetContext formatSegment" {
    const gpa = std.testing.allocator;
    const io = std.Io.threaded_global.ioBasic();
    var env_map = std.process.Environ.Map.init(gpa);
    defer env_map.deinit();

    var ctx = try WidgetContext.init(gpa, io, &env_map, "hard", false);
    defer ctx.deinit();

    const seg = try ctx.formatSegment(ctx.theme.success, "󰍛", 42);
    defer gpa.free(seg);

    try std.testing.expect(std.mem.containsAtLeast(u8, seg, 1, "#[fg="));
    try std.testing.expect(std.mem.containsAtLeast(u8, seg, 1, "󰍛"));
    try std.testing.expect(std.mem.containsAtLeast(u8, seg, 1, "42"));
}
