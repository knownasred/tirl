const u = @import("utils.zig");
const ty = @import("types.zig");

// Reminder of the objective
// Have an either finction that can be called in the following ways
pub fn either(comptime _: anytype) ty.Parser(void) {}

test "test that either can be called with anonymous parsers of different types" {}

test "test that either can be called with named parsers of different types" {}

test "test that either can be called with named parsers of same type" {}

test "test that either can be called with anonymous parsers of same type" {}
