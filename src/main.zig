const std = @import("std");

const zig_scene = @import("zig_scene");
const Image = zig_scene.renderer.Image;

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.skip();
    const path = args.next() orelse {
        std.debug.print("Usage: zig-scene <scene-file>\n", .{});
        return;
    };

    const cwd = std.Io.Dir.cwd();
    const f = try cwd.openFile(init.io, path, .{});
    defer f.close(init.io);

    var read_buf: [4096]u8 = undefined;
    var reader = f.reader(init.io, &read_buf);
    const content = try reader.interface.allocRemaining(alloc, .unlimited);

    const parsed = zig_scene.ast.file.parse(alloc, content);
    const file = switch (parsed) {
        .ok => |tree| tree,
        .err => |err| {
            var err_buf: [256]u8 = undefined;
            const stderr = std.Io.File.stderr();
            var err_out = stderr.writer(init.io, &err_buf);
            try err.display(&err_out.interface);
            try err_out.flush();
            return;
        },
    };

    const scene = zig_scene.interpreter.interpret(alloc, file) catch |err| {
        std.debug.print("Interpret error: {}\n", .{err});
        return;
    };

    const cli_progress = try zig_scene.tui.CliProgress.init(alloc, 1);
    try cli_progress.start(init.io);

    var camera = scene.camera;
    camera.renderMode = .perPixel;
    const image = try camera.render(alloc, cli_progress.progress(), &scene.world);

    const output = try cwd.createFile(init.io, "output.ppm", .{ .truncate = true });
    defer output.close(init.io);

    var write_buffer: [2048]u8 = undefined;
    var fw = output.writer(init.io, &write_buffer);
    try image.write(&fw.interface);
    try fw.flush();

    cli_progress.finish(init.io);
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa);
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
