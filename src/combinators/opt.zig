const utils = @import("utils.zig");
const parser = @import("parser.zig");
const std = @import("std");

pub fn opt(comptime t: anytype) parser.Parser(?utils.TypeOfParser(t).OutputType) {
    const OutputType = utils.TypeOfParser(t).OutputType;
    const OptType = ?OutputType;
    return .{
        .parse = struct {
            fn parse(alloc: std.mem.Allocator, p: *parser.State) parser.Result(OptType) {
                const cp = p.checkpoint();
                switch (t.parse(alloc, p)) {
                    .ok => |val| return parser.Ok(OptType, val),
                    .err => {
                        p.restore(cp);
                        return parser.Ok(OptType, null);
                    },
                }
            }
        }.parse,
    };
}

// ─── Tests ──────────────────────────────────────────────────────────────────

test "opt matches when wrapped parser succeeds" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime opt(lit.literal("hello"));

    var r = t.testParse(combinator, "hello world");
    try r.expectOk().expectValue({}).expectRest(" world").finish();
}

test "opt returns null when wrapped parser fails" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime opt(lit.literal("hello"));

    var r = t.testParse(combinator, "world");
    try r.expectOk().expectValue(null).expectRest("world").finish();
}

test "opt with value-producing parser succeeds" {
    const t = @import("utils.zig");
    const multi = @import("multi.zig");

    const combinator = comptime opt(multi.takeWhile(std.ascii.isDigit).notEmpty());

    var r = t.testParse(combinator, "123abc");
    try r.expectOk().expectValue(@as(?[]const u8, "123")).expectRest("abc").finish();
}

test "opt with value-producing parser returns null on failure" {
    const t = @import("utils.zig");
    const multi = @import("multi.zig");

    const combinator = comptime opt(multi.takeWhile(std.ascii.isDigit).notEmpty());

    var r = t.testParse(combinator, "abc");
    try r.expectOk().expectValue(null).expectRest("abc").finish();
}

test "opt rolls back state when wrapped parser advances then fails" {
    const t = @import("utils.zig");

    const failAfterAdvance = struct {
        fn parse(_: std.mem.Allocator, p: *parser.State) parser.Result([]const u8) {
            p.advance(3);
            return parser.Err([]const u8, parser.ErrorCode.UnexpectedToken, "intentional fail", p.checkpoint());
        }
    };
    const inner = comptime parser.Parser([]const u8){ .parse = failAfterAdvance.parse };
    const combinator = comptime opt(inner);

    var r = t.testParse(combinator, "abcdef");
    try r.expectOk().expectValue(null).expectRest("abcdef").finish();
}

test "opt matches at EOF returning null" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime opt(lit.literal("hello"));

    var r = t.testParse(combinator, "");
    try r.expectOk().expectValue(null).expectEof().finish();
}
