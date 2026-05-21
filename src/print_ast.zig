const std = @import("std");
const zig_scene = @import("zig_scene");

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.skip(); // skip program name
    const path = args.next() orelse {
        std.debug.print("Usage: print_ast <scene-file>\n", .{});
        return;
    };

    // Read the scene file
    const cwd = std.Io.Dir.cwd();
    const f = try cwd.openFile(init.io, path, .{});
    defer f.close(init.io);

    var read_buf: [4096]u8 = undefined;
    var reader = f.reader(init.io, &read_buf);
    const content = try reader.interface.allocRemaining(alloc, .unlimited);

    // Parse
    const result = zig_scene.ast.file.parse(alloc, content);

    // Write to stdout
    var out_buf: [4096]u8 = undefined;
    const stdout = std.Io.File.stdout();
    var out = stdout.writer(init.io, &out_buf);

    switch (result) {
        .ok => |tree| {
            try zig_scene.ast.print.printFile(tree, &out.interface);
        },
        .err => |err| {
            // Errors go to stderr
            var err_buf: [256]u8 = undefined;
            const stderr = std.Io.File.stderr();
            var err_out = stderr.writer(init.io, &err_buf);
            try err.display(&err_out.interface);
            try err_out.flush();
            return;
        },
    }

    try out.flush();
}
