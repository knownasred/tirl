const combinators = @import("../combinators/root.zig");
const std = @import("std");

pub const Symbol = struct {
    const combinator = combinators.lexme(
        combinators.recognize(
            combinators.seq(.{
                combinators.satisfy(std.ascii.isAlphabetic),
                combinators.takeWhile(std.ascii.isAlphanumeric),
            }),
        ),
    ).map(@This().toStruct).label("an identifier (e.g. foo, foo123)");

    fn toStruct(data: []const u8) @This() {
        return @This(){
            .value = data,
        };
    }

    value: []const u8,
};

test "Symbol parses a simple identifier" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Symbol.combinator, "foo");
    try r.expectOk().expectValue(Symbol{ .value = "foo" }).expectEof().finish();
}

test "Symbol parses an identifier with trailing alphanumeric characters" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Symbol.combinator, "foo123");
    try r.expectOk().expectValue(Symbol{ .value = "foo123" }).expectEof().finish();
}

test "Symbol fails when starting with a digit" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Symbol.combinator, "123foo");
    try r.expectErr().expectRest("123foo").finish();
}

test "Symbol fails on empty input" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Symbol.combinator, "");
    try r.expectErr().expectEof().finish();
}

test "Symbol skips trailing whitespace" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Symbol.combinator, "bar   ");
    try r.expectOk().expectValue(Symbol{ .value = "bar" }).expectEof().finish();
}

test "Symbol skips trailing comments" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Symbol.combinator, "baz# a comment\n");
    try r.expectOk().expectValue(Symbol{ .value = "baz" }).expectEof().finish();
}

test "Symbol parses identifier followed by other text" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Symbol.combinator, "hello world");
    try r.expectOk().expectValue(Symbol{ .value = "hello" }).expectRest("world").finish();
}

test "Symbol parses single alphabetic character" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Symbol.combinator, "x");
    try r.expectOk().expectValue(Symbol{ .value = "x" }).expectEof().finish();
}

test "Symbol fails on single digit" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Symbol.combinator, "5");
    try r.expectErr().expectRest("5").finish();
}

test "Symbol parses identifier with underscores if alphanumeric" {
    const t = @import("../combinators/utils.zig");

    // Note: std.ascii.isAlphanumeric does NOT include underscore, so "foo_bar"
    // will only parse "foo" and leave "_bar". Let's verify that behavior.
    var r = t.testParse(Symbol.combinator, "foo_bar");
    try r.expectOk().expectValue(Symbol{ .value = "foo" }).expectRest("_bar").finish();
}

test "Symbol error includes expected label" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Symbol.combinator, "123foo");
    try r.expectErr().expectExpected("an identifier (e.g. foo, foo123)").finish();
}

test "Symbol error at eof includes expected label" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Symbol.combinator, "");
    try r.expectErr().expectExpected("an identifier (e.g. foo, foo123)").finish();
}
