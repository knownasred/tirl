const std = @import("std");

const zig_scene = @import("zig_scene");
const Image = zig_scene.renderer.Image;
const Color3 = zig_scene.renderer.math.Color3;

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();

    const cli_progress = zig_scene.tui.CliProgress.init(alloc, 1);
    try cli_progress.start(init.io);

    // Now we can render!
    const image = try zig_scene.renderer.render(alloc, cli_progress.progress());

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

    // Actually finish
    cli_progress.finish(init.io);
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa);
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
