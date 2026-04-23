const parser = @import("parser.zig");
const utils = @import("utils.zig");
const litteral = @import("litteral.zig");
const std = @import("std");

fn isString(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |info| isString(info.child),
        .array => |info| info.child == u8,
        else => false,
    };
}

fn DelimType(comptime T: type) type {
    if (isString(T)) {
        return parser.Parser(void);
    } else {
        return T;
    }
}

fn makeDelim(comptime val: anytype) DelimType(@TypeOf(val)) {
    const T = @TypeOf(val);
    if (isString(T)) {
        return litteral.literal(val);
    } else {
        return val;
    }
}

/// delimited parses `open`, then `inner`, then `close`.
/// On success it returns the result of `inner`.
/// If any parser fails, the state is rolled back to the initial position.
///
/// `open` and `close` can be either parsers or string literals,
/// in which case they are automatically wrapped in `literal` parsers.
pub fn delimited(comptime open: anytype, comptime inner: anytype, comptime close: anytype) @TypeOf(inner) {
    const open_parser = comptime makeDelim(open);
    const close_parser = comptime makeDelim(close);
    const InnerParser = utils.TypeOfParser(inner);

    return .{
        .parse = struct {
            fn parse(alloc: std.mem.Allocator, p: *parser.State) InnerParser.ResultType {
                const initialCheckpoint = p.checkpoint();

                // Parse open
                const openResult = open_parser.parse(alloc, p);
                if (utils.isErr(openResult)) {
                    p.restore(initialCheckpoint);
                    return InnerParser.ResultType{ .err = .{
                        .code = .UnexpectedToken,
                        .desc = "delimited: open parser failed",
                        .expected = null,
                        .location = initialCheckpoint,
                    } };
                }

                // Parse inner
                const innerResult = inner.parse(alloc, p);
                if (utils.isErr(innerResult)) {
                    p.restore(initialCheckpoint);
                    return innerResult;
                }

                // Parse close
                const closeResult = close_parser.parse(alloc, p);
                if (utils.isErr(closeResult)) {
                    p.restore(initialCheckpoint);
                    return InnerParser.ResultType{ .err = .{
                        .code = .UnexpectedToken,
                        .desc = "delimited: close parser failed",
                        .expected = null,
                        .location = initialCheckpoint,
                    } };
                }

                return innerResult;
            }
        }.parse,
    };
}

// ─── Behaviour tests ──────────────────────────────────────────────────────────

test "delimited: all parsers match, returns inner result" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const open = comptime lit.literal("(");
    const inner = comptime lit.literal("hello").map(struct {
        fn map(_: void) []const u8 {
            return "hello";
        }
    }.map);
    const close = comptime lit.literal(")");
    const combinator = comptime delimited(open, inner, close);

    var r = t.testParse(combinator, "(hello)");
    try r.expectOk().expectValue("hello").expectEof().finish();
}

test "delimited: string open/close are auto-wrapped in literal" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const inner = comptime lit.literal("hello").map(struct {
        fn map(_: void) []const u8 {
            return "hello";
        }
    }.map);
    const combinator = comptime delimited("(", inner, ")");

    var r = t.testParse(combinator, "(hello)");
    try r.expectOk().expectValue("hello").expectEof().finish();
}

test "delimited: open fails, rolls back" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const inner = comptime lit.literal("hello");
    const combinator = comptime delimited("(", inner, ")");

    var r = t.testParse(combinator, "hello)");
    try r.expectErr().expectRest("hello)").finish();
}

test "delimited: inner fails, rolls back" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const inner = comptime lit.literal("hello");
    const combinator = comptime delimited("(", inner, ")");

    var r = t.testParse(combinator, "(world)");
    try r.expectErr().expectRest("(world)").finish();
}

test "delimited: close fails, rolls back" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const inner = comptime lit.literal("hello");
    const combinator = comptime delimited("(", inner, ")");

    var r = t.testParse(combinator, "(hello]");
    try r.expectErr().expectRest("(hello]").finish();
}

test "delimited: leaves remaining input after close" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const inner = comptime lit.literal("abc").map(struct {
        fn map(_: void) u32 {
            return 123;
        }
    }.map);
    const combinator = comptime delimited("[", inner, "]");

    var r = t.testParse(combinator, "[abc] rest");
    try r.expectOk().expectValue(123).expectRest(" rest").finish();
}

test "delimited: nested delimiters" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const inner = comptime lit.literal("inner");
    const combinator = comptime delimited("{", inner, "}");

    var r = t.testParse(combinator, "{inner} after");
    try r.expectOk().expectValue({}).expectRest(" after").finish();
}

test "delimited: empty inner with matching delimiters" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const inner = comptime lit.literal("");
    const combinator = comptime delimited("<", inner, ">");

    var r = t.testParse(combinator, "<>");
    try r.expectOk().expectValue({}).expectEof().finish();
}

test "delimited: inner is a more complex parser" {
    const t = @import("utils.zig");
    const multi = @import("multi.zig");

    const inner = comptime multi.takeWhile(struct {
        fn pred(c: u8) bool {
            return c != '"';
        }
    }.pred);
    const combinator = comptime delimited("\"", inner, "\"");

    var r = t.testParse(combinator, "\"hello world\"");
    try r.expectOk().expectValue("hello world").expectEof().finish();
}

test "delimited: string open/close with parser inner" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const inner = comptime lit.literal("content").map(struct {
        fn map(_: void) []const u8 {
            return "content";
        }
    }.map);
    const combinator = comptime delimited("{{", inner, "}}");

    var r = t.testParse(combinator, "{{content}}");
    try r.expectOk().expectValue("content").expectEof().finish();
}

test "delimited: multi-char string delimiters" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const inner = comptime lit.literal("hi");
    const combinator = comptime delimited("/*", inner, "*/");

    var r = t.testParse(combinator, "/*hi*/");
    try r.expectOk().expectValue({}).expectEof().finish();
}
