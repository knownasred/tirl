const parser = @import("parser.zig");
const std = @import("std");

pub fn recognize(comptime p: anytype) parser.Parser([]const u8) {
    return .{
        .parse = struct {
            fn parse(state: *parser.State) parser.Result([]const u8) {
                const checkpoint = state.checkpoint();

                // Execute the parser
                // if ok, returns the slice between the two elements
                const parseResult = p.parse(state);

                switch (parseResult) {
                    .ok => {
                        const newCp = state.checkpoint();

                        return parser.Ok([]const u8, state.data[checkpoint.pos..newCp.pos]);
                    },
                    .err => |err| {
                        return parser.Result([]const u8){ .err = .{
                            .code = err.code,
                            .desc = err.desc,
                            .expected = err.expected,
                            .location = err.location orelse checkpoint,
                        } };
                    },
                }
            }
        }.parse,
    };
}

test "recognize with literal parser returns matched text" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime recognize(lit.literal("hello"));

    var r = t.testParse(combinator, "hello world");
    try r.expectOk().expectValue("hello").expectRest(" world").finish();
}

test "recognize with literal parser fails when input does not match" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime recognize(lit.literal("hello"));

    var r = t.testParse(combinator, "goodbye");
    try r.expectErr().expectRest("goodbye").finish();
}

test "recognize with takeWhile returns consumed slice" {
    const t = @import("utils.zig");
    const multi = @import("multi.zig");

    const combinator = comptime recognize(multi.takeWhile(std.ascii.isDigit));

    var r = t.testParse(combinator, "12345abc");
    try r.expectOk().expectValue("12345").expectRest("abc").finish();
}

test "recognize with seq returns full matched slice" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");
    const seq = @import("seq.zig");

    const inner = comptime seq.seq(.{ lit.literal("ab"), lit.literal("cd") });
    const combinator = comptime recognize(inner);

    var r = t.testParse(combinator, "abcdxyz");
    try r.expectOk().expectValue("abcd").expectRest("xyz").finish();
}

test "recognize with seq fails and does not consume input" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");
    const seq = @import("seq.zig");

    const inner = comptime seq.seq(.{ lit.literal("ab"), lit.literal("cd") });
    const combinator = comptime recognize(inner);

    var r = t.testParse(combinator, "abxx");
    try r.expectErr().expectRest("abxx").finish();
}

test "recognize with empty takeWhile returns empty slice" {
    const t = @import("utils.zig");
    const multi = @import("multi.zig");

    const combinator = comptime recognize(multi.takeWhile(std.ascii.isDigit));

    var r = t.testParse(combinator, "abc");
    try r.expectOk().expectValue("").expectRest("abc").finish();
}

test "recognize at eof with literal returns matched slice" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime recognize(lit.literal("hello"));

    var r = t.testParse(combinator, "hello");
    try r.expectOk().expectValue("hello").expectEof().finish();
}
