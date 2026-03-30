const std = @import("std");
const zig_scene = @import("zig_scene");

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // ---- diag demo (codespan/rustc-ish) ----
    //
    // Render diagnostic directly to stderr so color can be auto-detected (TTY vs redirect).
    const diag = zig_scene.diag;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const src_text =
        \\const x: u32 = "hi";
        \\const y: u32 = 123;
        \\
    ;

    var src = try diag.Source.init(a, "main.zig", src_text);
    defer src.deinit(a);

    var d = diag.Diagnostic.init(a, .@"error", "mismatched types");
    defer d.deinit();
    d.code = "E0308";

    // Point at `"hi"` in the first line: `const x: u32 = "hi";`
    // Offsets here are byte offsets into `src_text`.
    try d.addLabel(
        .primary,
        .{ .file = &src, .range = .{ .start = 15, .end = 19 } },
        "expected `u32`, found `[]const u8`",
    );
    try d.addHint("try changing the literal to a number, e.g. `42`");
    try d.addNote("this is a tiny demo of a diagnostic renderer");

    std.debug.print("\n--- Exact diagnostic output (to stderr, auto color) ---\n", .{});
    try diag.renderToStderr(d, .{ .color = .auto });
    std.debug.print("-------------------------------\n", .{});
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa);
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
