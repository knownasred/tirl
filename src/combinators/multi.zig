const parser = @import("parser.zig");
const std = @import("std");

pub fn takeWhile(comptime pred: fn (u8) bool) parser.Parser([]const u8) {
    return .{
        .parse = struct {
            fn parse(pa: *parser.State) parser.Result([]const u8) {
                const cp = pa.checkpoint();

                if (pa.isEof()) {
                    return parser.Ok([]const u8, &.{});
                }

                // Note: The start pos is storysed in the checkpoint.
                var currentChar = pa.peek(1).?[0];
                while (pred(currentChar)) {
                    pa.advance(1);
                    if (pa.isEof()) break;
                    currentChar = pa.peek(1).?[0];
                }
                const finalPos = pa.checkpoint();
                // Return the slice between the last checkpoint and the end, if there are at least one character taken
                return parser.Ok([]const u8, pa.data[cp.pos..finalPos.pos]);
            }
        }.parse,
    };
}

test "Test simple takeWhile combinator" {
    const t = @import("utils.zig");

    const testCombinator = comptime takeWhile(std.ascii.isDigit);

    var r1 = t.testParse(testCombinator, "123test");
    try r1.expectOk().expectValue("123").finish();

    var r2 = t.testParse(testCombinator, "meuh");
    try r2.expectOk().expectValue("").finish();
}

test "takeWhile with the notEmpty wrapper" {
    const t = @import("utils.zig");

    const testCombinator = comptime takeWhile(std.ascii.isDigit).notEmpty();

    var r1 = t.testParse(testCombinator, "123test");
    try r1.expectOk().expectValue("123").finish();

    var r2 = t.testParse(testCombinator, "meuh");
    try r2.expectErr().finish();
}
