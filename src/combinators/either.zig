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

fn EitherParserType(comptime obj: anytype) type {
    return switch (@typeInfo(@TypeOf(obj))) {
        .pointer => EitherParserType(*obj),
        .@"struct" => |t| {
            const fields_len = t.fields.len;
            const intType = std.math.IntFittingRange(0, fields_len - 1);

            // Check if it is a tuple, and all fields are the same type
            if (t.is_tuple and allFieldsHaveSameType(t)) {
                return t.fields[0].type;
            }

            var field_names: [fields_len][]const u8 = undefined;
            var field_types: [fields_len]type = undefined;
            var field_attributes: [fields_len]std.builtin.Type.UnionField.Attributes = undefined;
            inline for (0.., t.fields) |i, field| {
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
        },
        else => |T| @compileError("expected struct or *struct, got " ++ @typeName(T)),
    };
}

// Reminder of the objective
// Have an either finction that can be called in the following ways
pub fn either(comptime t: anytype) EitherParserType(t) {
    const ParserType = EitherParserType(t);

    return .{ .parse = struct {
        fn parse(p: *parser.State) ParserType.ResultType {
            return parser.Err(ParserType.OutputType, parser.ErrorCode.ReadError, "unimplemented...", p.checkpoint());
        }
    }.parse };
}

test "test that either can be called with anonymous parsers of different types" {
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

test "test that either can be called with named parsers of different types" {
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

test "test that either can be called with named parsers of same type" {
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

test "test that either can be called with anonymous parsers of same type" {
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
