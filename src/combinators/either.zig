const utils = @import("utils.zig");
const parser = @import("parser.zig");
const std = @import("std");

const typeTools = @import("type_tools/types_equals.zig");

fn allFieldsHaveSameType(structType: std.builtin.Type.Struct) bool {
    if (structType.fields.len == 0) {
        // Ignore the case where there are no fields.
        return false;
    }
    const firstType = structType.fields[0].type;

    inline for (structType.fields) |field| {
        if (field.type != firstType) {
            return false;
        }
    }
    return true;
}

fn extractStruct(comptime obj: anytype) std.builtin.Type.Struct {
    return switch (@typeInfo(@TypeOf(obj))) {
        .pointer => extractStruct(*obj),
        .@"struct" => |t| t,
        else => |T| @compileError("expected struct or *struct, got " ++ @typeName(T)),
    };
}

fn EitherParserType(comptime obj: anytype) type {
    const structType = extractStruct(obj);
    const fields_len = structType.fields.len;
    const intType = std.math.IntFittingRange(0, fields_len - 1);

    // Check if it is a tuple, and all fields are the same type
    if (structType.is_tuple and allFieldsHaveSameType(structType)) {
        return structType.fields[0].type;
    }

    var field_names: [fields_len][]const u8 = undefined;
    var field_types: [fields_len]type = undefined;
    var field_attributes: [fields_len]std.builtin.Type.UnionField.Attributes = undefined;
    inline for (0.., structType.fields) |i, field| {
        field_names[i] = field.name;
        field_types[i] = field.type.OutputType;
        field_attributes[i] = .{};
    }

    var field_names_ids: [field_names.len]intType = undefined;
    for (0..field_names.len) |i| {
        field_names_ids[i] = i;
    }
    const enumVal = @Enum(intType, .exhaustive, &field_names, &field_names_ids);
    return parser.Parser(@Union(.auto, enumVal, &field_names, &field_types, &field_attributes));
}

// Reminder of the objective
// Have an either finction that can be called in the following ways
pub fn either(comptime t: anytype) EitherParserType(t) {
    const ParserType = EitherParserType(t);
    const elemStruct = extractStruct(t);

    return .{
        .parse = struct {
            fn parse(p: *parser.State) ParserType.ResultType {
                const initialCheckpoint = p.checkpoint();

                inline for (elemStruct.fields) |field| {
                    // Attempt
                    const parseResult = @field(t, field.name).parse(p);

                    switch (parseResult) {
                        .ok => |ok| {
                            if (comptime (elemStruct.is_tuple and allFieldsHaveSameType(elemStruct))) {
                                return ParserType.Ok(ok);
                            }

                            // Create the enum variant
                            const returnVariant = @unionInit(ParserType.OutputType, field.name, ok);

                            return ParserType.Ok(returnVariant);
                        },
                        .err => {
                            // Rollback
                            p.restore(initialCheckpoint);
                        },
                    }
                }

                if (elemStruct.is_tuple) {
                    return parser.Err(ParserType.OutputType, parser.ErrorCode.ReadError, "Nothing matched, ex!", p.checkpoint());
                } else {
                    const fields = comptime blk: {
                        var str: []const u8 = "";
                        for (elemStruct.fields, 0..) |field, i| {
                            if (i > 0) {
                                str = str ++ ", ";
                            }
                            str = str ++ field.name;
                        }

                        break :blk str;
                    };
                    return parser.Err(ParserType.OutputType, parser.ErrorCode.UnexpectedToken, "Nothing matched, expected one of: " ++ fields ++ ".", p.checkpoint());
                }
            }
        }.parse,
    };
}

test "test that either can be called with anonymous parsers of different types and work and returns an union" {
    const multi = @import("multi.zig");
    const lit = @import("litteral.zig");

    const testCombinator = comptime either(.{ multi.takeWhile(std.ascii.isAlphabetic), lit.literal("1234").map(struct {
        fn map(_: void) u32 {
            return 1;
        }
    }.map) });

    // Check the return type
    const returnType = @TypeOf(testCombinator).OutputType;

    typeTools.assertTypesMatch(union(enum) { @"0": []const u8, @"1": u32 }, returnType);
}

test "test that either can be called with named parsers of different types and returns an union" {
    const multi = @import("multi.zig");
    const lit = @import("litteral.zig");

    const testCombinator = comptime either(.{ .first = multi.takeWhile(std.ascii.isAlphabetic), .second = lit.literal("1234").map(struct {
        fn map(_: void) u32 {
            return 1;
        }
    }.map) });

    // Check the return type
    const returnType = @TypeOf(testCombinator).OutputType;

    typeTools.assertTypesMatch(union(enum) { first: []const u8, second: u32 }, returnType);
}

test "test that either can be called with named parsers of same type does not compact" {
    const multi = @import("multi.zig");
    const lit = @import("litteral.zig");

    const testCombinator = comptime either(.{ .first = multi.takeWhile(std.ascii.isAlphabetic), .second = lit.literal("1234").map(struct {
        fn map(_: void) []const u8 {
            return "mehmeh";
        }
    }.map) });

    // Check the return type
    const returnType = @TypeOf(testCombinator).OutputType;

    // NOTE: Because of how I want it to work, if it is named, then the compression won't happen
    typeTools.assertTypesMatch(union(enum) { first: []const u8, second: []const u8 }, returnType);
}

test "test that either can be called with anonymous parsers of same type compacts" {
    const multi = @import("multi.zig");
    const lit = @import("litteral.zig");

    const testCombinator = comptime either(.{ multi.takeWhile(std.ascii.isAlphabetic), lit.literal("1234").map(struct {
        fn map(_: void) []const u8 {
            return "mehmeh";
        }
    }.map) });

    const returnType = @TypeOf(testCombinator).OutputType;

    // NOTE: Because it is a tuple, type compaction is allowed
    typeTools.assertTypesMatch([]const u8, returnType);
}

test "either with anonymous parsers of different types: first parser matches" {
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
    const combinator = comptime either(.{ p1, p2 });

    const result = t.testParse(combinator, "hello");
    switch (result) {
        .ok => |val| switch (val) {
            .@"0" => |inner| try std.testing.expectEqual(@as(u32, 42), inner),
            else => return error.TestUnexpectedResult,
        },
        .err => |err| {
            std.log.err("Expected ok, got: {s}", .{err.desc});
            return error.TestUnexpectedResult;
        },
    }
}

test "either with anonymous parsers of different types: second parser matches" {
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
    const combinator = comptime either(.{ p1, p2 });

    const result = t.testParse(combinator, "world");
    switch (result) {
        .ok => |val| switch (val) {
            .@"1" => |inner| try std.testing.expectEqualStrings("world", inner),
            else => return error.TestUnexpectedResult,
        },
        .err => |err| {
            std.log.err("Expected ok, got: {s}", .{err.desc});
            return error.TestUnexpectedResult;
        },
    }
}

test "either with anonymous parsers of different types: no match returns ReadError" {
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
    const combinator = comptime either(.{ p1, p2 });

    const result = t.testParse(combinator, "foobar");
    switch (result) {
        .ok => return error.TestUnexpectedResult,
        .err => |err| try std.testing.expectEqual(parser.ErrorCode.ReadError, err.code),
    }
}

test "either with named parsers of different types: first parser matches" {
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
    const combinator = comptime either(.{ .first = p1, .second = p2 });

    const result = t.testParse(combinator, "hello");
    switch (result) {
        .ok => |val| switch (val) {
            .first => |inner| try std.testing.expectEqual(@as(u32, 42), inner),
            else => return error.TestUnexpectedResult,
        },
        .err => |err| {
            std.log.err("Expected ok, got: {s}", .{err.desc});
            return error.TestUnexpectedResult;
        },
    }
}

test "either with named parsers of different types: second parser matches" {
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
    const combinator = comptime either(.{ .first = p1, .second = p2 });

    const result = t.testParse(combinator, "world");
    switch (result) {
        .ok => |val| switch (val) {
            .second => |inner| try std.testing.expectEqualStrings("world", inner),
            else => return error.TestUnexpectedResult,
        },
        .err => |err| {
            std.log.err("Expected ok, got: {s}", .{err.desc});
            return error.TestUnexpectedResult;
        },
    }
}

test "either with named parsers of different types: no match returns UnexpectedToken" {
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
    const combinator = comptime either(.{ .first = p1, .second = p2 });

    const result = t.testParse(combinator, "foobar");
    switch (result) {
        .ok => return error.TestUnexpectedResult,
        .err => |err| try std.testing.expectEqual(parser.ErrorCode.UnexpectedToken, err.code),
    }
}

test "either with anonymous same-type parsers: first matches, returns value directly" {
    const t = @import("utils.zig");
    const multi = @import("multi.zig");

    const p1 = comptime multi.takeWhile(std.ascii.isAlphabetic).notEmpty();
    const p2 = comptime multi.takeWhile(std.ascii.isDigit).notEmpty();
    const combinator = comptime either(.{ p1, p2 });

    const result = t.testParse(combinator, "hello123");
    try t.isOkAndEq(result, "hello");
}

test "either with anonymous same-type parsers: second matches when first fails" {
    const t = @import("utils.zig");
    const multi = @import("multi.zig");

    const p1 = comptime multi.takeWhile(std.ascii.isAlphabetic).notEmpty();
    const p2 = comptime multi.takeWhile(std.ascii.isDigit).notEmpty();
    const combinator = comptime either(.{ p1, p2 });

    const result = t.testParse(combinator, "123hello");
    try t.isOkAndEq(result, "123");
}

test "either with anonymous same-type parsers: no match returns error" {
    const t = @import("utils.zig");
    const multi = @import("multi.zig");

    const p1 = comptime multi.takeWhile(std.ascii.isAlphabetic).notEmpty();
    const p2 = comptime multi.takeWhile(std.ascii.isDigit).notEmpty();
    const combinator = comptime either(.{ p1, p2 });

    const result = t.testParse(combinator, "!@#");
    try std.testing.expect(t.isErr(result));
}

test "either with named same-type parsers: first matches, returns named union variant" {
    const t = @import("utils.zig");
    const multi = @import("multi.zig");

    const p1 = comptime multi.takeWhile(std.ascii.isAlphabetic).notEmpty();
    const p2 = comptime multi.takeWhile(std.ascii.isDigit).notEmpty();
    const combinator = comptime either(.{ .letters = p1, .digits = p2 });

    const result = t.testParse(combinator, "hello123");
    switch (result) {
        .ok => |val| switch (val) {
            .letters => |s| try std.testing.expectEqualStrings("hello", s),
            else => return error.TestUnexpectedResult,
        },
        .err => |err| {
            std.log.err("Expected ok, got: {s}", .{err.desc});
            return error.TestUnexpectedResult;
        },
    }
}

test "either with named same-type parsers: second matches, returns named union variant" {
    const t = @import("utils.zig");
    const multi = @import("multi.zig");

    const p1 = comptime multi.takeWhile(std.ascii.isAlphabetic).notEmpty();
    const p2 = comptime multi.takeWhile(std.ascii.isDigit).notEmpty();
    const combinator = comptime either(.{ .letters = p1, .digits = p2 });

    const result = t.testParse(combinator, "123hello");
    switch (result) {
        .ok => |val| switch (val) {
            .digits => |s| try std.testing.expectEqualStrings("123", s),
            else => return error.TestUnexpectedResult,
        },
        .err => |err| {
            std.log.err("Expected ok, got: {s}", .{err.desc});
            return error.TestUnexpectedResult;
        },
    }
}

test "either: rolls back state when first parser advances and fails" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    // A parser that consumes 3 bytes then unconditionally fails.
    // Shares OutputType ([]const u8) with the second parser so either() uses
    // compact mode — the result is Result([]const u8) directly, letting us
    // call t.isOkAndEq without unwrapping a union.
    const failAfterAdvance = struct {
        fn parse(p: *parser.State) parser.Result([]const u8) {
            p.advance(3);
            return parser.Err([]const u8, parser.ErrorCode.UnexpectedToken, "intentional fail", p.checkpoint());
        }
    };
    const p1 = comptime parser.Parser([]const u8){ .parse = failAfterAdvance.parse };
    const p2 = comptime lit.literal("abc").map(struct {
        fn map(_: void) []const u8 {
            return "abc";
        }
    }.map);
    const combinator = comptime either(.{ p1, p2 });

    // p1 advances 3 bytes then errors; either must restore pos to 0 before
    // trying p2, which then matches the full "abc" from the start.
    const result = t.testParse(combinator, "abc");
    try t.isOkAndEq(result, "abc");
}
