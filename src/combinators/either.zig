const u = @import("utils.zig");
const ty = @import("types.zig");
const std = @import("std");

fn EitherReturnType(comptime _: anytype) void {
    // It is an array of types.
}
fn assertSameType(comptime A: type, comptime B: type) void {
    if (A != B) @compileError("Type mismatch: expected " ++ @typeName(A) ++ ", got " ++ @typeName(B));
}
// Reminder of the objective
// Have an either finction that can be called in the following ways
pub fn either(comptime _: anytype) ty.ParserElem(void) {}

test "test that either can be called with anonymous parsers of different types" {
    const multi = @import("multi.zig");
    const lit = @import("litteral.zig");

    const testCombinator = comptime either(.{ multi.takeWhile(std.ascii.isAlphabetic), lit.literal("1234").map(struct {
        fn map(_: void) u8 {
            return 1;
        }
    }.map) });

    // Check the return type
    const returnType = u.InnerReturnType(testCombinator);

    assertSameType(union(enum) { @"1": []const u8, @"2": u8 }, returnType);
}

test "test that either can be called with named parsers of different types" {}

test "test that either can be called with named parsers of same type" {}

test "test that either can be called with anonymous parsers of same type" {}
