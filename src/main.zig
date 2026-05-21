const std = @import("std");
const zig_scene = @import("zig_scene");

const Image = zig_scene.renderer.Image;
const Color3 = zig_scene.renderer.math.Color3;
pub fn main(init: std.process.Init) !void {
    const image_width = 256;
    const image_height = 256;

    const alloc = init.arena.allocator();

    var image = try Image.create(alloc, image_width, image_height);
    defer image.deinit(alloc);

    for (0..image_height) |row| {
        for (0..image_width) |col| {
            image.set(row, col, Color3.new(
                @as(f32, @floatFromInt(col)) / (@as(f32, @floatFromInt(image_width)) - 1),
                @as(f32, @floatFromInt(row)) / (@as(f32, @floatFromInt(image_height)) - 1),
                0.0,
            ));
        }
    }

    // Write down to a file
    const cwd = std.Io.Dir.cwd();
    const file = try cwd.createFile(init.io, "output.ppm", .{
        .truncate = true,
    });
    defer file.close(init.io);

    var write_buffer: [2048]u8 = undefined;

    var fw = file.writer(init.io, &write_buffer);

    try image.write(&fw.interface);

    try fw.flush();
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa);
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
