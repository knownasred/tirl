const parser = @import("parser.zig");
const std = @import("std");
const typeTools = @import("type_tools/types_equals.zig");

fn extractStruct(comptime obj: anytype) std.builtin.Type.Struct {
    return switch (@typeInfo(@TypeOf(obj))) {
        .pointer => extractStruct(*obj),
        .@"struct" => |t| t,
        else => |T| @compileError("expected struct or *struct, got " ++ @typeName(T)),
    };
}

fn SeqParserType(comptime obj: anytype) type {
    const structType = extractStruct(obj);
    const fields_len = structType.fields.len;

    if (!structType.is_tuple) {
        @compileError("Only tuples are accepted in the then parser type");
    }

    var field_types: [fields_len]type = undefined;

    inline for (0.., structType.fields) |i, field| {
        field_types[i] = field.type.OutputType;
    }

    return parser.Parser(@Tuple(&field_types));
}

/// seq is an seq-or-nothing combinator.
///
/// If seq the parsers passed as a parameter of seq matches in order, and in that case,
/// a tuple of seq results is provided in the Ok Result variant
///
/// Or at least one parser failed, and the State is rolled back (no characters will be consumed)
/// and an error Response variant is returned with the furthest error.
pub fn seq(comptime t: anytype) SeqParserType(t) {
    const ParserType = SeqParserType(t);
    const elemStruct = extractStruct(t);

    return .{
        .parse = struct {
            fn parse(alloc: std.mem.Allocator, p: *parser.State) ParserType.ResultType {
                const initialCheckpoint = p.checkpoint();

                var result: ParserType.OutputType = undefined;

                inline for (elemStruct.fields) |field| {
                    const parseResult = @field(t, field.name).parse(alloc, p);

                    switch (parseResult) {
                        .ok => |ok| {
                            // Store it in the resulting element
                            @field(result, field.name) = ok;
                        },
                        .err => |err| {
                            // Rollback
                            p.restore(initialCheckpoint);

                            // And return the resulting error, preserving the expected field
                            return ParserType.ResultType{ .err = .{
                                .code = err.code,
                                .desc = err.desc,
                                .expected = err.expected,
                                .location = err.location orelse initialCheckpoint,
                            } };
                        },
                    }
                }

                // return the (by now) fully initialized result
                return ParserType.Ok(result);
            }
        }.parse,
    };
}

// ─── Type tests ───────────────────────────────────────────────────────────────

test "seq with anonymous parsers returns a tuple of output types" {
    const lit = @import("litteral.zig");
    const multi = @import("multi.zig");

    const p1 = comptime lit.literal("abc").map(struct {
        fn map(_: void) u32 {
            return 42;
        }
    }.map);
    const p2 = comptime multi.takeWhile(std.ascii.isAlphabetic);

    const combinator = comptime seq(.{ p1, p2 });
    const OutputType = @TypeOf(combinator).OutputType;

    typeTools.assertTypesMatch(@Tuple(&.{ u32, []const u8 }), OutputType);
}

test "seq with void parsers returns a tuple of voids" {
    const lit = @import("litteral.zig");

    const p1 = comptime lit.literal("abc");
    const p2 = comptime lit.literal("def");

    const combinator = comptime seq(.{ p1, p2 });
    const OutputType = @TypeOf(combinator).OutputType;

    typeTools.assertTypesMatch(@Tuple(&.{ void, void }), OutputType);
}

// ─── Behaviour tests ──────────────────────────────────────────────────────────

test "seq: seq parsers match, returns tuple of results" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const p1 = comptime lit.literal("hello").map(struct {
        fn map(_: void) u32 {
            return 42;
        }
    }.map);
    const p2 = comptime lit.literal("world").map(struct {
        fn map(_: void) []const u8 {
            return "world";
        }
    }.map);
    const combinator = comptime seq(.{ p1, p2 });

    var r = t.testParse(combinator, "helloworld");
    try r.expectOk().expectValue(.{ 42, "world" }).finish();
}

test "seq: first parser fails, returns error and rolls back" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const p1 = comptime lit.literal("hello");
    const p2 = comptime lit.literal("world");
    const combinator = comptime seq(.{ p1, p2 });

    var r = t.testParse(combinator, "goodbye world");
    try r.expectErr().expectRest("goodbye world").finish();
}

test "seq: second parser fails, returns error and rolls back" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const p1 = comptime lit.literal("hello");
    const p2 = comptime lit.literal("world");
    const combinator = comptime seq(.{ p1, p2 });

    var r = t.testParse(combinator, "hellouniverse");
    try r.expectErr().expectRest("hellouniverse").finish();
}

test "seq: single parser in tuple works" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const p1 = comptime lit.literal("hello").map(struct {
        fn map(_: void) u32 {
            return 99;
        }
    }.map);
    const combinator = comptime seq(.{p1});

    var r = t.testParse(combinator, "hello");
    try r.expectOk().expectValue(.{99}).finish();
}

test "seq: three parsers match in order" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const p1 = comptime lit.literal("a");
    const p2 = comptime lit.literal("b");
    const p3 = comptime lit.literal("c");
    const combinator = comptime seq(.{ p1, p2, p3 });

    var r = t.testParse(combinator, "abc");
    try r.expectOk().expectValue(.{ {}, {}, {} }).finish();
}

test "seq: three parsers, middle fails, rolls back" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const p1 = comptime lit.literal("a");
    const p2 = comptime lit.literal("b");
    const p3 = comptime lit.literal("c");
    const combinator = comptime seq(.{ p1, p2, p3 });

    var r = t.testParse(combinator, "axc");
    try r.expectErr().expectRest("axc").finish();
}

test "seq: first parser advances then second fails, state is fully rolled back" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");
    const multi = @import("multi.zig");

    const p1 = comptime multi.takeWhile(std.ascii.isAlphabetic);
    const p2 = comptime lit.literal("123");
    const combinator = comptime seq(.{ p1, p2 });

    var r = t.testParse(combinator, "hello456");
    try r.expectErr().expectRest("hello456").finish();
}
