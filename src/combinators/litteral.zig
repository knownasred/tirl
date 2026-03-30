const types = @import("types.zig");
const std = @import("std");

pub fn literal(comptime expected: []const u8) types.ParserElem(void) {
    return .{
        .parse = struct {
            fn parse(pa: *types.Parser) types.ParserResult(void) {
                const cp = pa.checkpoint();
                // Try and check literally:
                const actual = pa.peek(expected.len) orelse return types.Err(void, types.ErrorCode.UnexpectedEOF, "Expected tokem, found end of file.", cp);
                if (!std.mem.startsWith(u8, actual, expected))
                    return types.Err(void, types.ErrorCode.UnexpectedToken, "Unexpected token!", cp);
                pa.advance(expected.len);
                return types.Ok(void, void{});
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
