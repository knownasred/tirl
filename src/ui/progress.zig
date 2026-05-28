const std = @import("std");
const renderer = @import("../renderer/root.zig");
const Color3 = renderer.math.Color3;

pub const UiProgress = struct {
    display_buffer: []Color3,
    width: usize,
    height: usize,
    current: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    total: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    cancelled: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn init(alloc: std.mem.Allocator, width: usize, height: usize) !*UiProgress {
        const self = try alloc.create(UiProgress);
        const buffer = try alloc.alloc(Color3, width * height);
        @memset(buffer, Color3.new(0, 0, 0));
        self.* = .{
            .display_buffer = buffer,
            .width = width,
            .height = height,
        };
        return self;
    }

    pub fn progress(self: *UiProgress) renderer.Progress(UiProgress) {
        return .{ .context = self };
    }

    pub fn increment(self: *UiProgress, amount: u64) bool {
        _ = self.current.fetchAdd(amount, .monotonic);
        return self.cancelled.load(.monotonic);
    }

    pub fn cancel(self: *UiProgress) void {
        self.cancelled.store(true, .monotonic);
    }

    pub fn setTotal(self: *UiProgress, total: u64) void {
        self.total.store(total, .monotonic);
    }

    pub fn onPixel(self: *UiProgress, row: usize, col: usize, sample: usize, color: Color3) void {
        _ = sample;
        self.display_buffer[row * self.width + col] = color;
    }
};
