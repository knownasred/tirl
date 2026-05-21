const std = @import("std");
const vec3 = @import("../math/vec3.zig");
const Vec3 = vec3.Vec3;
const Color3 = vec3.Color3;

pub const Image = struct {
    buffer: []Color3,
    width: usize,
    height: usize,

    pub fn create(alloc: std.mem.Allocator, width: usize, height: usize) !@This() {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        const buffer = try alloc.alloc(Color3, width * height);
        @memset(buffer, Color3.from(Vec3.zero()));
        return .{
            .width = width,
            .height = height,
            .buffer = buffer,
        };
    }

    pub fn set(self: @This(), row: usize, col: usize, color: Color3) void {
        std.debug.assert(row < self.height);
        std.debug.assert(col < self.width);
        self.buffer[row * self.width + col] = color;
    }

    pub fn get(self: @This(), row: usize, col: usize) Color3 {
        std.debug.assert(row < self.height);
        std.debug.assert(col < self.width);
        return self.buffer[row * self.width + col];
    }

    pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
        alloc.free(self.buffer);
    }

    /// Writes an image in the PPM format.
    pub fn write(self: @This(), writer: *std.Io.Writer) !void {
        try writer.printAscii("P3\n", .{});
        try writer.printInt(self.width, 10, .lower, .{});
        try writer.printAsciiChar(' ', .{});
        try writer.printInt(self.height, 10, .lower, .{});

        try writer.printAscii("\n255\n", .{});

        for (0..self.height) |row| {
            for (0..self.width) |col| {
                try printColor(writer, self.buffer[row * self.width + col]);
            }
        }
    }

    fn printColor(writer: *std.Io.Writer, color: Color3) !void {
        try writer.printInt(@as(u8, @intFromFloat(color.getX() * 255.999)), 10, .lower, .{});
        try writer.printAsciiChar(' ', .{});
        try writer.printInt(@as(u8, @intFromFloat(color.getY() * 255.999)), 10, .lower, .{});
        try writer.printAsciiChar(' ', .{});
        try writer.printInt(@as(u8, @intFromFloat(color.getZ() * 255.999)), 10, .lower, .{});
        try writer.printAsciiChar('\n', .{});
    }
};

test "Image create initializes width and height" {
    const img = try Image.create(std.testing.allocator, 4, 3);
    defer img.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), img.width);
    try std.testing.expectEqual(@as(usize, 3), img.height);
}

test "Image set and get roundtrip" {
    var img = try Image.create(std.testing.allocator, 4, 3);
    defer img.deinit(std.testing.allocator);

    const red = Color3.new(1.0, 0.0, 0.0);
    const green = Color3.new(0.0, 1.0, 0.0);
    const blue = Color3.new(0.0, 0.0, 1.0);

    img.set(0, 0, red);
    img.set(2, 3, green);
    img.set(1, 1, blue);

    try std.testing.expect(img.get(0, 0).equal(red));
    try std.testing.expect(img.get(2, 3).equal(green));
    try std.testing.expect(img.get(1, 1).equal(blue));
}

test "Image set overwrites previous value" {
    var img = try Image.create(std.testing.allocator, 2, 2);
    defer img.deinit(std.testing.allocator);

    const first = Color3.new(0.25, 0.5, 0.75);
    const second = Color3.new(0.1, 0.2, 0.3);

    img.set(1, 0, first);
    img.set(1, 0, second);

    try std.testing.expect(img.get(1, 0).equal(second));
}

test "Image deinit frees the buffer" {
    // Relies on std.testing.allocator to detect leaks.
    const img = try Image.create(std.testing.allocator, 8, 8);
    img.deinit(std.testing.allocator);
}

test "Image write produces a valid PPM" {
    var img = try Image.create(std.testing.allocator, 3, 2);
    defer img.deinit(std.testing.allocator);

    img.set(0, 0, Color3.new(1.0, 0.0, 0.0));
    img.set(0, 1, Color3.new(0.0, 1.0, 0.0));
    img.set(0, 2, Color3.new(0.0, 0.0, 1.0));
    img.set(1, 0, Color3.new(1.0, 1.0, 0.0));
    img.set(1, 1, Color3.new(1.0, 1.0, 1.0));
    img.set(1, 2, Color3.new(0.0, 0.0, 0.0));

    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try img.write(&out.writer);

    const expected =
        "P3\n" ++
        "3 2\n" ++
        "255\n" ++
        "255 0 0\n" ++
        "0 255 0\n" ++
        "0 0 255\n" ++
        "255 255 0\n" ++
        "255 255 255\n" ++
        "0 0 0\n";
    try std.testing.expectEqualStrings(expected, out.written());
}
