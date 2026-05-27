const std = @import("std");
const combinators = @import("../combinators/root.zig");
const parser = @import("../combinators/parser.zig");
const literal = @import("../combinators/litteral.zig").literal;
const Label = @import("label.zig").Label;
const Symbol = @import("symbol.zig").Symbol;
const t = @import("../combinators/utils.zig");

pub const Value = union(enum) {
    string: Label,
    boolean: bool,
    number: f64,
    call: struct {
        name: Symbol,
        args: []const Value,
    },
    reference: Label,

    pub const combinator = parser.Parser(Value){ .parse = parseValue };
};

fn parseValue(alloc: std.mem.Allocator, p: *parser.State) parser.Result(Value) {
    // string
    switch (Label.combinator.parse(alloc, p)) {
        .ok => |v| return .{ .ok = .{ .string = v } },
        .err => {},
    }

    // boolean
    switch (combinators.lexme(literal("true")).parse(alloc, p)) {
        .ok => return .{ .ok = .{ .boolean = true } },
        .err => {},
    }
    switch (combinators.lexme(literal("false")).parse(alloc, p)) {
        .ok => return .{ .ok = .{ .boolean = false } },
        .err => {},
    }

    // number
    switch (parseNumber(alloc, p)) {
        .ok => |v| return .{ .ok = .{ .number = v } },
        .err => {},
    }

    // reference (@"name")
    switch (combinators.lexme(literal("@")).parse(alloc, p)) {
        .ok => switch (Label.combinator.parse(alloc, p)) {
            .ok => |v| return .{ .ok = .{ .reference = v } },
            .err => |e| return .{ .err = e },
        },
        .err => {},
    }

    // call (Vec3(...), Quat(...), ...)
    return parseCall(alloc, p);
}

fn parseNumber(alloc: std.mem.Allocator, p: *parser.State) parser.Result(f64) {
    const start = p.checkpoint();
    const raw = combinators.lexme(combinators.recognize(combinators.seq(.{
        combinators.seq(.{ combinators.satisfy(std.ascii.isDigit), combinators.takeWhile(std.ascii.isDigit) }),
        combinators.opt(combinators.seq(.{
            literal("."),
            combinators.seq(.{ combinators.satisfy(std.ascii.isDigit), combinators.takeWhile(std.ascii.isDigit) }),
        })),
    }))).parse(alloc, p);

    switch (raw) {
        .ok => |s| return .{ .ok = std.fmt.parseFloat(f64, s) catch {
            p.restore(start);
            return .{ .err = .{ .code = .ValueTooBig, .desc = "invalid number", .expected = "a number", .location = null } };
        } },
        .err => |e| return .{ .err = e },
    }
}

fn parseCall(alloc: std.mem.Allocator, p: *parser.State) parser.Result(Value) {
    const cp = p.checkpoint();

    const name = switch (Symbol.combinator.parse(alloc, p)) {
        .ok => |v| v,
        .err => |e| return .{ .err = e },
    };

    const args = switch (combinators.delimited(lparen, combinators.separated(Value.combinator, comma), rparen).parse(alloc, p)) {
        .ok => |v| v,
        .err => |e| {
            p.restore(cp);
            return .{ .err = e };
        },
    };

    return .{ .ok = .{ .call = .{ .name = name, .args = args } } };
}

const lparen = combinators.lexme(literal("("));
const rparen = combinators.lexme(literal(")"));
const comma = combinators.lexme(literal(","));

test "value: parses a string" {
    var r = t.testParse(Value.combinator, "\"hello\"");
    try r.expectOk().expectValue(Value{ .string = .{ .value = "hello" } }).expectEof().finish();
}

test "value: parses true" {
    var r = t.testParse(Value.combinator, "true");
    try r.expectOk().expectValue(Value{ .boolean = true }).expectEof().finish();
}

test "value: parses false" {
    var r = t.testParse(Value.combinator, "false");
    try r.expectOk().expectValue(Value{ .boolean = false }).expectEof().finish();
}

test "value: parses an integer" {
    var r = t.testParse(Value.combinator, "42");
    try r.expectOk().expectValue(Value{ .number = 42.0 }).expectEof().finish();
}

test "value: parses a float" {
    var r = t.testParse(Value.combinator, "3.14");
    try r.expectOk().expectValue(Value{ .number = 3.14 }).expectEof().finish();
}

test "value: parses a reference" {
    var r = t.testParse(Value.combinator, "@\"TestMaterial\"");
    try r.expectOk().expectValue(Value{ .reference = .{ .value = "TestMaterial" } }).expectEof().finish();
}

test "value: parses a call with no args" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var state = parser.State.init("Foo()");
    const result = Value.combinator.parse(arena.allocator(), &state);
    try std.testing.expect(result == .ok);
    try std.testing.expectEqualStrings("Foo", result.ok.call.name.value);
    try std.testing.expectEqual(@as(usize, 0), result.ok.call.args.len);
}

test "value: parses a call with args" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var state = parser.State.init("Vec3(1.0, 2.0, 3.0)");
    const result = Value.combinator.parse(arena.allocator(), &state);
    try std.testing.expect(result == .ok);
    try std.testing.expectEqualStrings("Vec3", result.ok.call.name.value);
    try std.testing.expectEqual(@as(usize, 3), result.ok.call.args.len);
    try std.testing.expectEqual(Value{ .number = 1.0 }, result.ok.call.args[0]);
    try std.testing.expectEqual(Value{ .number = 2.0 }, result.ok.call.args[1]);
    try std.testing.expectEqual(Value{ .number = 3.0 }, result.ok.call.args[2]);
}

test "value: parses nested calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var state = parser.State.init("Outer(Inner(1.0))");
    const result = Value.combinator.parse(arena.allocator(), &state);
    try std.testing.expect(result == .ok);
    try std.testing.expectEqualStrings("Outer", result.ok.call.name.value);
    try std.testing.expectEqual(@as(usize, 1), result.ok.call.args.len);
    try std.testing.expectEqualStrings("Inner", result.ok.call.args[0].call.name.value);
}

test "value: fails on invalid input" {
    var r = t.testParse(Value.combinator, "}{");
    try r.expectErr().finish();
}
