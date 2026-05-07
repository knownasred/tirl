const utils = @import("utils.zig");
const parser = @import("parser.zig");
const std = @import("std");

pub fn many0(comptime t: anytype) parser.Parser([]utils.TypeOfParser(t).OutputType) {
    const OutputType = utils.TypeOfParser(t).OutputType;
    const SliceType = []OutputType;
    return .{
        .parse = struct {
            fn parse(alloc: std.mem.Allocator, p: *parser.State) parser.Result(SliceType) {
                var checkpoint: parser.State.Checkpoint = undefined;
                var list: std.ArrayList(OutputType) = .empty;

                loop: while (true) {
                    checkpoint = p.checkpoint();
                    // try and parse
                    switch (t.parse(alloc, p)) {
                        .ok => |val| {
                            const after = p.checkpoint();
                            if (after.pos == checkpoint.pos) {
                                // parser succeeded but consumed nothing — prevent infinite loop
                                break :loop;
                            }
                            list.append(alloc, val) catch return parser.AllocErr(SliceType);
                        },
                        .err => {
                            p.restore(checkpoint);
                            break :loop;
                        },
                    }
                }

                // Return the array
                if (list.items.len == 0) {
                    list.deinit(alloc);
                    return .{ .ok = &.{} };
                }
                const slice = list.toOwnedSlice(alloc) catch return parser.AllocErr(SliceType);
                return .{ .ok = slice };
            }
        }.parse,
    };
}

pub fn many1(comptime t: anytype) parser.Parser([]utils.TypeOfParser(t).OutputType) {
    return many0(t).notEmpty();
}

// ─── Tests ──────────────────────────────────────────────────────────────────

test "many0 matches zero occurrences" {
    const lit = @import("litteral.zig");
    const combinator = comptime many0(lit.literal("a"));

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var state = parser.State.init("bbb");
    const result = combinator.parse(arena.allocator(), &state);
    try std.testing.expectEqualDeep(&[_]void{}, result.ok);
    try std.testing.expectEqualStrings("bbb", state.rest());
}

test "many0 matches multiple occurrences" {
    const lit = @import("litteral.zig");
    const combinator = comptime many0(lit.literal("a"));

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var state = parser.State.init("aaab");
    const result = combinator.parse(arena.allocator(), &state);
    const expected = [_]void{ {}, {}, {} };
    try std.testing.expectEqualDeep(&expected, result.ok);
    try std.testing.expectEqualStrings("b", state.rest());
}

test "many0 matches until EOF" {
    const lit = @import("litteral.zig");
    const combinator = comptime many0(lit.literal("a"));

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var state = parser.State.init("aaa");
    const result = combinator.parse(arena.allocator(), &state);
    const expected = [_]void{ {}, {}, {} };
    try std.testing.expectEqualDeep(&expected, result.ok);
    try std.testing.expect(state.isEof());
}

test "many1 fails on zero occurrences" {
    const lit = @import("litteral.zig");
    const combinator = comptime many1(lit.literal("a"));

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var state = parser.State.init("bbb");
    const result = combinator.parse(arena.allocator(), &state);
    try std.testing.expect(result == .err);
}

test "many1 matches at least one occurrence" {
    const lit = @import("litteral.zig");
    const combinator = comptime many1(lit.literal("a"));

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var state = parser.State.init("aab");
    const result = combinator.parse(arena.allocator(), &state);
    const expected = [_]void{ {}, {} };
    try std.testing.expectEqualDeep(&expected, result.ok);
    try std.testing.expectEqualStrings("b", state.rest());
}

test "many0 with takeWhile collects one slice then stops" {
    const multi = @import("multi.zig");
    const combinator = comptime many0(multi.takeWhile(std.ascii.isDigit));

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var state = parser.State.init("123abc456");
    const result = combinator.parse(arena.allocator(), &state);
    const expected = [_][]const u8{"123"};
    try std.testing.expectEqualDeep(&expected, result.ok);
    try std.testing.expectEqualStrings("abc456", state.rest());
}

test "many1 with takeWhile fails when no digits" {
    const multi = @import("multi.zig");
    const combinator = comptime many1(multi.takeWhile(std.ascii.isDigit));

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var state = parser.State.init("abc");
    const result = combinator.parse(arena.allocator(), &state);
    try std.testing.expect(result == .err);
}
