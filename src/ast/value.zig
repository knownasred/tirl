const std = @import("std");
const combinators = @import("../combinators/root.zig");
const parser = @import("../combinators/parser.zig");
const literal = @import("../combinators/litteral.zig").literal;
const Label = @import("label.zig").Label;
const Symbol = @import("symbol.zig").Symbol;

pub const Value = union(enum) {
    string: Label,
    boolean: bool,
    number: f64,
    call: struct {
        name: Symbol,
        args: []const Value,
    },

    pub const combinator = parser.Parser(Value){ .parse = parseValue };
};

fn parseValue(alloc: std.mem.Allocator, p: *parser.State) parser.Result(Value) {
    // Try string
    switch (Label.combinator.parse(alloc, p)) {
        .ok => |v| return .{ .ok = .{ .string = v } },
        .err => {},
    }

    // Try boolean
    switch (combinators.lexme(literal("true")).parse(alloc, p)) {
        .ok => return .{ .ok = .{ .boolean = true } },
        .err => {},
    }
    switch (combinators.lexme(literal("false")).parse(alloc, p)) {
        .ok => return .{ .ok = .{ .boolean = false } },
        .err => {},
    }

    // Try number
    switch (parseNumber(alloc, p)) {
        .ok => |v| return .{ .ok = .{ .number = v } },
        .err => {},
    }

    // Try call (Vec3(...))
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

    switch (lparen.parse(alloc, p)) {
        .ok => {},
        .err => |e| {
            p.restore(cp);
            return .{ .err = e };
        },
    }

    var args: std.ArrayList(Value) = .empty;

    const before_first = p.checkpoint();
    switch (parseValue(alloc, p)) {
        .ok => |first| {
            args.append(alloc, first) catch return parser.AllocErr(Value);
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
                switch (parseValue(alloc, p)) {
                    .ok => |v| args.append(alloc, v) catch return parser.AllocErr(Value),
                    .err => {
                        p.restore(before_next);
                        break;
                    },
                }
            }
        },
        .err => p.restore(before_first),
    }

    switch (rparen.parse(alloc, p)) {
        .ok => {},
        .err => |e| {
            args.deinit(alloc);
            p.restore(cp);
            return .{ .err = e };
        },
    }

    const slice = args.toOwnedSlice(alloc) catch return parser.AllocErr(Value);
    return .{ .ok = .{ .call = .{ .name = name, .args = slice } } };
}

const lparen = combinators.lexme(literal("("));
const rparen = combinators.lexme(literal(")"));
const comma = combinators.lexme(literal(","));
