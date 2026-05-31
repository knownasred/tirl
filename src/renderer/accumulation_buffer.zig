const std = @import("std");
const math = @import("math/root.zig");
const Vec3 = math.Vec3;
const Color3 = math.Color3;
const toFloat = math.toFloat;

pub const AccumulationBuffer = struct {
    buffer: []Vec3,
    width: usize,
    height: usize,
    samples: usize,

    pub fn create(alloc: std.mem.Allocator, width: usize, height: usize) !AccumulationBuffer {
        const buffer = try alloc.alloc(Vec3, width * height);
        @memset(buffer, Vec3.zero());
        return .{
            .buffer = buffer,
            .width = width,
            .height = height,
            .samples = 0,
        };
    }

    pub fn accumulate(self: *AccumulationBuffer, row: usize, col: usize, color: Vec3) void {
        self.buffer[row * self.width + col] = self.buffer[row * self.width + col].add(color);
    }

    pub fn averaged(self: *const AccumulationBuffer, row: usize, col: usize) Color3 {
        return .from(self.buffer[row * self.width + col].mul_s(1.0 / toFloat(self.samples)));
    }

    pub fn incrementSamples(self: *AccumulationBuffer) void {
        self.samples += 1;
    }

    pub fn setSamples(self: *AccumulationBuffer, samples: usize) void {
        self.samples = samples;
    }

    pub fn deinit(self: AccumulationBuffer, alloc: std.mem.Allocator) void {
        alloc.free(self.buffer);
    }
};
