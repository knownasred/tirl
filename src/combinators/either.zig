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
    var array: [field_names.len]intType = undefined;
    for (0..field_names.len) |i| {
        array[i] = i;
    }
    const enumVal = @Enum(intType, .exhaustive, &field_names, &array);
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
