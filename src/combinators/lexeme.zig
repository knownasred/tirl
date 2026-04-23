const parser = @import("parser.zig");
const utils = @import("utils.zig");
const std = @import("std");
const takeWhile = @import("multi.zig").takeWhile;

fn skipWs() parser.Parser(void) {
    const p = parser.Parser(void);
    return .{
        .parse = struct {
            fn parse(state: *parser.State) p.ResultType {
                mainLoop: while (!state.isEof()) {
                    const char = state.peek(1).?[0];
                    switch (char) {
                        ' ', '\t', '\n', '\r' => state.advance(1),
                        '#' => {
                            // Take while
                            _ = takeWhile(struct {
                                fn pred(val: u8) bool {
                                    return val != '\n';
                                }
                            }.pred).parse(state);
                        },
                        else => break :mainLoop,
                    }
                }

                return p.Ok(void{});
            }
        }.parse,
    };
}

pub fn lexeme(comptime p: anytype) @TypeOf(p) {
    const P = @TypeOf(p);
    return .{
        .parse = struct {
            fn parse(state: *parser.State) P.ResultType {
                const result = p.parse(state);

                if (utils.isOk(result)) {
                    _ = skipWs().parse(state);
                }

                return result;
            }
        }.parse,
    };
}

test "lexeme skips trailing whitespace" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime lexeme(lit.literal("hello"));
    var r = t.testParse(combinator, "hello   world");
    try r.expectOk().expectRest("world").finish();
}

test "lexeme skips trailing spaces and tabs" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime lexeme(lit.literal("abc"));
    var r = t.testParse(combinator, "abc\t\t xyz");
    try r.expectOk().expectRest("xyz").finish();
}

test "lexeme skips trailing newlines" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime lexeme(lit.literal("abc"));
    var r = t.testParse(combinator, "abc\n\r\nxyz");
    try r.expectOk().expectRest("xyz").finish();
}

test "lexeme skips trailing comments" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime lexeme(lit.literal("abc"));
    var r = t.testParse(combinator, "abc# this is a comment\nxyz");
    try r.expectOk().expectRest("xyz").finish();
}

test "lexeme does not skip whitespace on parse failure" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime lexeme(lit.literal("hello"));
    var r = t.testParse(combinator, "world");
    try r.expectErr().expectRest("world").finish();
}

test "lexeme advances state past whitespace" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime lexeme(lit.literal("hello"));
    var r = t.testParse(combinator, "hello   world");
    try r.expectOk().expectRest("world").finish();
}

test "lexeme advances state past comment" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime lexeme(lit.literal("abc"));
    var r = t.testParse(combinator, "abc# comment\nnext");
    try r.expectOk().expectRest("next").finish();
}

test "lexeme works with no trailing whitespace" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime lexeme(lit.literal("abc"));
    var r = t.testParse(combinator, "abc");
    try r.expectOk().expectEof().finish();
}

test "skipWs skips spaces" {
    var state = parser.State.init("   hello");
    const result = skipWs().parse(&state);
    try std.testing.expect(utils.isOk(result));
    try std.testing.expectEqualStrings("hello", state.rest());
}

test "skipWs skips tabs and newlines" {
    var state = parser.State.init("\t\n\r\nhello");
    const result = skipWs().parse(&state);
    try std.testing.expect(utils.isOk(result));
    try std.testing.expectEqualStrings("hello", state.rest());
}

test "skipWs skips comments until newline" {
    var state = parser.State.init("# this is a comment\nhello");
    const result = skipWs().parse(&state);
    try std.testing.expect(utils.isOk(result));
    try std.testing.expectEqualStrings("hello", state.rest());
}

test "skipWs stops at non-whitespace" {
    var state = parser.State.init("hello");
    const result = skipWs().parse(&state);
    try std.testing.expect(utils.isOk(result));
    try std.testing.expectEqualStrings("hello", state.rest());
}

test "skipWs at eof returns ok" {
    var state = parser.State.init("");
    const result = skipWs().parse(&state);
    try std.testing.expect(utils.isOk(result));
    try std.testing.expect(state.isEof());
}
