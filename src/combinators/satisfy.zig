const parser = @import("parser.zig");
const std = @import("std");

pub fn satisfy(comptime pred: fn (char: u8) bool) parser.Parser(u8) {
    return .{
        .parse = struct {
            fn parse(_: std.mem.Allocator, state: *parser.State) parser.Result(u8) {
                // No need to checkpoint tbh
                if (state.isEof()) {
                    return parser.Err(u8, parser.ErrorCode.UnexpectedEOF, "Unexpected EOF", state.checkpoint());
                }
                const char = state.peek(1).?[0];

                if (pred(char)) {
                    state.advance(1);
                    return parser.Ok(u8, char);
                } else {
                    return parser.Err(u8, parser.ErrorCode.UnexpectedToken, "Unexpected token", state.checkpoint());
                }
            }
        }.parse,
    };
}

test "satisfy matches when predicate returns true" {
    const t = @import("utils.zig");

    const combinator = comptime satisfy(std.ascii.isAlphabetic);

    var r = t.testParse(combinator, "abc");
    try r.expectOk().expectValue('a').expectRest("bc").finish();
}

test "satisfy fails when predicate returns false" {
    const t = @import("utils.zig");

    const combinator = comptime satisfy(std.ascii.isAlphabetic);

    var r = t.testParse(combinator, "123");
    try r.expectErr().expectErrorCode(parser.ErrorCode.UnexpectedToken).expectRest("123").finish();
}

test "satisfy fails at eof" {
    const t = @import("utils.zig");

    const combinator = comptime satisfy(std.ascii.isAlphabetic);

    var r = t.testParse(combinator, "");
    try r.expectErr().expectErrorCode(parser.ErrorCode.UnexpectedEOF).expectEof().finish();
}

test "satisfy matches digit predicate" {
    const t = @import("utils.zig");

    const combinator = comptime satisfy(std.ascii.isDigit);

    var r = t.testParse(combinator, "7up");
    try r.expectOk().expectValue('7').expectRest("up").finish();
}

test "satisfy with isWhitespace matches space" {
    const t = @import("utils.zig");

    const combinator = comptime satisfy(std.ascii.isWhitespace);

    var r = t.testParse(combinator, " hello");
    try r.expectOk().expectValue(' ').expectRest("hello").finish();
}

test "satisfy advances state by exactly one character" {
    const t = @import("utils.zig");

    const combinator = comptime satisfy(struct {
        fn pred(c: u8) bool {
            return c == '@';
        }
    }.pred);

    var r = t.testParse(combinator, "@test");
    try r.expectOk().expectValue('@').expectRest("test").finish();
}
