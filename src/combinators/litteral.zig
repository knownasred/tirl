const parser = @import("parser.zig");
const std = @import("std");

pub fn literal(comptime expected: []const u8) parser.Parser(void) {
    return .{
        .parse = struct {
            fn parse(pa: *parser.State) parser.Result(void) {
                const cp = pa.checkpoint();
                // Try and check literally:
                const actual = pa.peek(expected.len) orelse return parser.Err(void, parser.ErrorCode.UnexpectedEOF, "Expected token, found end of file.", cp);
                if (!std.mem.startsWith(u8, actual, expected))
                    return parser.Err(void, parser.ErrorCode.UnexpectedToken, "Unexpected token!", cp);
                pa.advance(expected.len);
                return parser.Ok(void, void{});
            }
        }.parse,
    };
}

test "Test simple combinator" {
    const t = @import("utils.zig");
    const testing = std.testing;

    const testCombinator = comptime literal("test").map(struct {
        fn f(_: void) i32 {
            return 1;
        }
    }.f);

    const okResult = t.testParse(testCombinator, "test");
    try testing.expect(t.isOk(okResult));
    const errResult = t.testParse(testCombinator, "meuh");
    try testing.expect(t.isErr(errResult));
}
