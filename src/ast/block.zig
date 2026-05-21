// A block is an identifier (the object type), followed by a label
// immedialy followed by one or more elements delimited by braces ({}),
// which could either be a block, or a list of attributes
//
// block_body      = lbrace, separated_list(item, comma), opt(comma), rbrace
// item            = seq(ident, alt(attribute_tail, block_tail))
// attribute_tail  = seq(colon, value)
// block_tail      = seq(string, block_body)

const std = @import("std");
const combinators = @import("../combinators/root.zig");
const parser = @import("../combinators/parser.zig");
const literal = @import("../combinators/litteral.zig").literal;
const Symbol = @import("symbol.zig").Symbol;
const Label = @import("label.zig").Label;

// `value` is left undefined by the grammar; treat it as a quoted string for now.
pub const Value = Label;

pub const Attribute = struct {
    name: Symbol,
    value: Value,
};

pub const Block = struct {
    type_name: Symbol,
    label: Label,
    body: []const Item,
};

pub const Item = union(enum) {
    attribute: Attribute,
    block: Block,
};

const lbrace = combinators.lexme(literal("{"));
const rbrace = combinators.lexme(literal("}"));
const comma = combinators.lexme(literal(","));
const colon = combinators.lexme(literal(":"));

pub const item = parser.Parser(Item){ .parse = parseItem };
pub const block_body = parser.Parser([]const Item){ .parse = parseBlockBody };

fn parseItem(alloc: std.mem.Allocator, p: *parser.State) parser.Result(Item) {
    const cp = p.checkpoint();

    const name = switch (Symbol.combinator.parse(alloc, p)) {
        .ok => |v| v,
        .err => |err| return .{ .err = err },
    };

    const after_ident = p.checkpoint();
    switch (colon.parse(alloc, p)) {
        .ok => {
            switch (Label.combinator.parse(alloc, p)) {
                .ok => |val| return .{ .ok = .{ .attribute = .{ .name = name, .value = val } } },
                .err => |err| {
                    p.restore(cp);
                    return .{ .err = err };
                },
            }
        },
        .err => p.restore(after_ident),
    }

    const block_label = switch (Label.combinator.parse(alloc, p)) {
        .ok => |v| v,
        .err => |err| {
            p.restore(cp);
            return .{ .err = err };
        },
    };

    switch (parseBlockBody(alloc, p)) {
        .ok => |body| return .{ .ok = .{ .block = .{
            .type_name = name,
            .label = block_label,
            .body = body,
        } } },
        .err => |err| {
            p.restore(cp);
            return .{ .err = err };
        },
    }
}

fn parseBlockBody(alloc: std.mem.Allocator, p: *parser.State) parser.Result([]const Item) {
    const cp = p.checkpoint();

    switch (lbrace.parse(alloc, p)) {
        .ok => {},
        .err => |err| return .{ .err = err },
    }

    var list: std.ArrayList(Item) = .empty;

    const before_first = p.checkpoint();
    switch (parseItem(alloc, p)) {
        .ok => |first| {
            list.append(alloc, first) catch return parser.AllocErr([]const Item);

            while (true) {
                const before_sep = p.checkpoint();
                switch (comma.parse(alloc, p)) {
                    .ok => {},
                    .err => {
                        p.restore(before_sep);
                        break;
                    },
                }

                const before_next = p.checkpoint();
                switch (parseItem(alloc, p)) {
                    .ok => |next| list.append(alloc, next) catch return parser.AllocErr([]const Item),
                    .err => {
                        p.restore(before_next);
                        break;
                    },
                }
            }
        },
        .err => p.restore(before_first),
    }

    switch (rbrace.parse(alloc, p)) {
        .ok => {},
        .err => |err| {
            list.deinit(alloc);
            p.restore(cp);
            return .{ .err = err };
        },
    }

    if (list.items.len == 0) {
        list.deinit(alloc);
        return .{ .ok = &.{} };
    }

    const slice = list.toOwnedSlice(alloc) catch return parser.AllocErr([]const Item);
    return .{ .ok = slice };
}

// ─── Tests ──────────────────────────────────────────────────────────────────

fn runItem(arena_alloc: std.mem.Allocator, input: []const u8) struct {
    result: parser.Result(Item),
    state: parser.State,
} {
    var state = parser.State.init(input);
    const result = item.parse(arena_alloc, &state);
    return .{ .result = result, .state = state };
}

test "item: parses an attribute" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const r = runItem(arena.allocator(), "foo: \"bar\"");
    const expected = Item{ .attribute = .{
        .name = .{ .value = "foo" },
        .value = .{ .value = "bar" },
    } };
    try std.testing.expectEqualDeep(expected, r.result.ok);
    try std.testing.expect(r.state.isEof());
}

test "item: parses an empty block" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const r = runItem(arena.allocator(), "foo \"label\" {}");
    const expected = Item{ .block = .{
        .type_name = .{ .value = "foo" },
        .label = .{ .value = "label" },
        .body = &.{},
    } };
    try std.testing.expectEqualDeep(expected, r.result.ok);
    try std.testing.expect(r.state.isEof());
}

test "item: parses a block with one attribute" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const r = runItem(arena.allocator(), "foo \"l\" { a: \"b\" }");
    const expected_body = [_]Item{.{ .attribute = .{
        .name = .{ .value = "a" },
        .value = .{ .value = "b" },
    } }};
    const expected = Item{ .block = .{
        .type_name = .{ .value = "foo" },
        .label = .{ .value = "l" },
        .body = &expected_body,
    } };
    try std.testing.expectEqualDeep(expected, r.result.ok);
    try std.testing.expect(r.state.isEof());
}

test "item: parses a block with multiple attributes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const r = runItem(arena.allocator(), "foo \"l\" { a: \"1\", b: \"2\", c: \"3\" }");
    const expected_body = [_]Item{
        .{ .attribute = .{ .name = .{ .value = "a" }, .value = .{ .value = "1" } } },
        .{ .attribute = .{ .name = .{ .value = "b" }, .value = .{ .value = "2" } } },
        .{ .attribute = .{ .name = .{ .value = "c" }, .value = .{ .value = "3" } } },
    };
    const expected = Item{ .block = .{
        .type_name = .{ .value = "foo" },
        .label = .{ .value = "l" },
        .body = &expected_body,
    } };
    try std.testing.expectEqualDeep(expected, r.result.ok);
    try std.testing.expect(r.state.isEof());
}

test "item: allows trailing comma in block body" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const r = runItem(arena.allocator(), "foo \"l\" { a: \"1\", b: \"2\", }");
    const expected_body = [_]Item{
        .{ .attribute = .{ .name = .{ .value = "a" }, .value = .{ .value = "1" } } },
        .{ .attribute = .{ .name = .{ .value = "b" }, .value = .{ .value = "2" } } },
    };
    const expected = Item{ .block = .{
        .type_name = .{ .value = "foo" },
        .label = .{ .value = "l" },
        .body = &expected_body,
    } };
    try std.testing.expectEqualDeep(expected, r.result.ok);
    try std.testing.expect(r.state.isEof());
}

test "item: parses nested blocks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const r = runItem(arena.allocator(), "outer \"o\" { inner \"i\" { x: \"y\" } }");
    const inner_body = [_]Item{.{ .attribute = .{
        .name = .{ .value = "x" },
        .value = .{ .value = "y" },
    } }};
    const outer_body = [_]Item{.{ .block = .{
        .type_name = .{ .value = "inner" },
        .label = .{ .value = "i" },
        .body = &inner_body,
    } }};
    const expected = Item{ .block = .{
        .type_name = .{ .value = "outer" },
        .label = .{ .value = "o" },
        .body = &outer_body,
    } };
    try std.testing.expectEqualDeep(expected, r.result.ok);
    try std.testing.expect(r.state.isEof());
}

test "item: mixes attributes and nested blocks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const r = runItem(arena.allocator(), "root \"r\" { a: \"1\", sub \"s\" {}, b: \"2\" }");
    const sub_body: []const Item = &.{};
    const root_body = [_]Item{
        .{ .attribute = .{ .name = .{ .value = "a" }, .value = .{ .value = "1" } } },
        .{ .block = .{
            .type_name = .{ .value = "sub" },
            .label = .{ .value = "s" },
            .body = sub_body,
        } },
        .{ .attribute = .{ .name = .{ .value = "b" }, .value = .{ .value = "2" } } },
    };
    const expected = Item{ .block = .{
        .type_name = .{ .value = "root" },
        .label = .{ .value = "r" },
        .body = &root_body,
    } };
    try std.testing.expectEqualDeep(expected, r.result.ok);
    try std.testing.expect(r.state.isEof());
}

test "item: skips whitespace and comments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const r = runItem(arena.allocator(),
        \\foo  "l"  {
        \\  # comment
        \\  a: "1",
        \\  b: "2"
        \\}
    );
    const body = [_]Item{
        .{ .attribute = .{ .name = .{ .value = "a" }, .value = .{ .value = "1" } } },
        .{ .attribute = .{ .name = .{ .value = "b" }, .value = .{ .value = "2" } } },
    };
    const expected = Item{ .block = .{
        .type_name = .{ .value = "foo" },
        .label = .{ .value = "l" },
        .body = &body,
    } };
    try std.testing.expectEqualDeep(expected, r.result.ok);
    try std.testing.expect(r.state.isEof());
}

test "item: fails when input does not start with an identifier" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const r = runItem(arena.allocator(), "\"label\" {}");
    try std.testing.expect(r.result == .err);
    try std.testing.expectEqualStrings("\"label\" {}", r.state.rest());
}

test "item: fails when neither attribute_tail nor block_tail follows ident" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const r = runItem(arena.allocator(), "foo bar");
    try std.testing.expect(r.result == .err);
    try std.testing.expectEqualStrings("foo bar", r.state.rest());
}

test "block_body: parses empty body" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var state = parser.State.init("{}");
    const result = block_body.parse(arena.allocator(), &state);
    try std.testing.expectEqual(@as(usize, 0), result.ok.len);
    try std.testing.expect(state.isEof());
}
