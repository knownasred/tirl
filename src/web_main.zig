const std = @import("std");
const zig_scene = @import("zig_scene");

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.skip();

    const port_str = args.next() orelse "8080";
    const port = std.fmt.parseInt(u16, port_str, 10) catch {
        std.debug.print("Invalid port: {s}\n", .{port_str});
        return;
    };

    try zig_scene.web.server.run(alloc, port, init.io);
}
