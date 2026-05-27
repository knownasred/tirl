const std = @import("std");
const renderer = @import("../renderer/root.zig");
const Color3 = renderer.math.Color3;

pub const UiProgress = struct {
    display_buffer: []Color3,
    width: usize,
    height: usize,

    pub fn init(alloc: std.mem.Allocator, width: usize, height: usize) *UiProgress {
        const self = alloc.create(UiProgress) catch unreachable;
        const buffer = alloc.alloc(Color3, width * height) catch unreachable;
        @memset(buffer, Color3.new(0, 0, 0));
        self.display_buffer = buffer;
        self.width = width;
        self.height = height;
        return self;
    }

    pub fn progress(self: *UiProgress) renderer.Progress(UiProgress) {
        return .{ .context = self };
    }

    pub fn increment(self: *UiProgress, amount: u64) void {
        _ = .{ self, amount };
    }

    pub fn setTotal(self: *UiProgress, total: u64) void {
        _ = .{ self, total };
    }

    pub fn onPixel(self: *UiProgress, row: usize, col: usize, sample: usize, color: Color3) void {
        _ = sample;
        self.display_buffer[row * self.width + col] = color;
    }
};
