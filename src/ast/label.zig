const combinators = @import("../combinators/root.zig");
const std = @import("std");

const ascii = std.ascii;

pub const Label = struct {
    const combinator = combinators.lexme(combinators.delimited("\"", combinators.takeWhile(struct {
        fn pred(char: u8) bool {
            return ascii.isAlphanumeric(char) or switch (char) {
                ',', '.', '-', '_', '$' => true,
                else => false,
            };
        }
    }.pred), "\"")).map(@This().toStruct).label("a quoted identifier (e.g. \"test\"");

    fn toStruct(data: []const u8) @This() {
        return @This(){
            .value = data,
        };
    }

    value: []const u8,
};

test "Label parses a simple quoted identifier" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Label.combinator, "\"foo\"");
    try r.expectOk().expectValue(Label{ .value = "foo" }).expectEof().finish();
}

test "Label parses a quoted identifier with allowed special chars" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Label.combinator, "\"hello.world-test_$\"");
    try r.expectOk().expectValue(Label{ .value = "hello.world-test_$" }).expectEof().finish();
}

test "Label parses a quoted identifier with digits" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Label.combinator, "\"foo123\"");
    try r.expectOk().expectValue(Label{ .value = "foo123" }).expectEof().finish();
}

test "Label fails when missing opening quote" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Label.combinator, "foo\"");
    try r.expectErr().expectRest("foo\"").finish();
}

test "Label fails when missing closing quote" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Label.combinator, "\"foo");
    try r.expectErr().expectRest("\"foo").finish();
}

test "Label fails on empty input" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Label.combinator, "");
    try r.expectErr().expectEof().finish();
}

test "Label parses empty quoted string" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Label.combinator, "\"\"");
    try r.expectOk().expectValue(Label{ .value = "" }).expectEof().finish();
}

test "Label skips trailing whitespace" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Label.combinator, "\"bar\"   ");
    try r.expectOk().expectValue(Label{ .value = "bar" }).expectEof().finish();
}

test "Label skips trailing comments" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Label.combinator, "\"baz\"# a comment\n");
    try r.expectOk().expectValue(Label{ .value = "baz" }).expectEof().finish();
}

test "Label fails on unquoted identifier" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Label.combinator, "hello");
    try r.expectErr().expectRest("hello").finish();
}

test "Label error includes expected label" {
    const t = @import("../combinators/utils.zig");

    var r = t.testParse(Label.combinator, "notquoted");
    try r.expectErr().expectExpected("a quoted identifier (e.g. \"test\"").finish();
}

test "Label fails on disallowed special characters inside quotes" {
    const t = @import("../combinators/utils.zig");

    // '^' is not in the allowed character set, so parsing stops at '^'
    var r = t.testParse(Label.combinator, "\"foo^bar\"");
    try r.expectErr().expectExpected("a quoted identifier (e.g. \"test\"").finish();
}
