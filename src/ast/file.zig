const std = @import("std");
const combinators = @import("../combinators/root.zig");
const parser = @import("../combinators/parser.zig");
const block = @import("block.zig");

pub const File = struct {
    items: []const block.Item,
};

fn toFile(items: []block.Item) File {
    return .{ .items = items };
}

pub const combinator = parser.Parser(File){ .parse = parseFile };

fn parseFile(alloc: std.mem.Allocator, p: *parser.State) parser.Result(File) {
    // Skip any leading whitespace or comments before the first block.
    // lexeme only handles trailing whitespace, so we do this explicitly here.
    _ = combinators.skipWs().parse(alloc, p);
    return switch (combinators.many0(block.item).parse(alloc, p)) {
        .ok => |items| .{ .ok = toFile(items) },
        .err => |err| .{ .err = err },
    };
}

/// Convenience: parse a scene string without manually constructing a State.
pub fn parse(alloc: std.mem.Allocator, input: []const u8) parser.Result(File) {
    var state = parser.State.init(input);
    return combinator.parse(alloc, &state);
}

// ─── Tests ──────────────────────────────────────────────────────────────────

test "file: parses empty input" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var state = parser.State.init("");
    const result = combinator.parse(arena.allocator(), &state);
    try std.testing.expect(result == .ok);
    try std.testing.expectEqual(@as(usize, 0), result.ok.items.len);
    try std.testing.expect(state.isEof());
}

test "file: parses a single top-level block" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var state = parser.State.init(
        \\Camera "main" { fov: "60" }
    );
    const result = combinator.parse(arena.allocator(), &state);
    try std.testing.expect(result == .ok);
    try std.testing.expectEqual(@as(usize, 1), result.ok.items.len);
    try std.testing.expect(state.isEof());
}

test "file: parses multiple top-level blocks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var state = parser.State.init(
        \\Camera "main" { fov: "60" }
        \\Group "scene" {}
    );
    const result = combinator.parse(arena.allocator(), &state);
    try std.testing.expect(result == .ok);
    try std.testing.expectEqual(@as(usize, 2), result.ok.items.len);
    try std.testing.expect(state.isEof());
}

test "file: handles comments and blank lines between blocks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var state = parser.State.init(
        \\# scene file
        \\Camera "main" {}
        \\
        \\# objects
        \\Group "scene" { Sphere "ball" { radius: "1" } }
    );
    const result = combinator.parse(arena.allocator(), &state);
    try std.testing.expect(result == .ok);
    try std.testing.expectEqual(@as(usize, 2), result.ok.items.len);
    try std.testing.expect(state.isEof());
}

test "file: preserves block contents" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var state = parser.State.init(
        \\Camera "main" { fov: "90", near: "0.1" }
    );
    const result = combinator.parse(arena.allocator(), &state);
    try std.testing.expect(result == .ok);
    const blk = result.ok.items[0].block;
    try std.testing.expectEqualStrings("Camera", blk.type_name.value);
    try std.testing.expectEqualStrings("main", blk.label.value);
    try std.testing.expectEqual(@as(usize, 2), blk.body.len);
}
