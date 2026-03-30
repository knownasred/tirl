const p = @import("types.zig");
const std = @import("std");
pub fn isErr(parser: anytype) bool {
    return switch (parser) {
        .err => true,
        .ok => false,
    };
}

pub fn isOk(parser: anytype) bool {
    return !isErr(parser);
}
pub fn isOkAndEq(parser: anytype, val: anytype) !void {
    switch (parser) {
        .ok => |value| {
            try std.testing.expectEqualDeep(val, value);
        },
        .err => |err| {
            // Print
            std.log.err("Expected OK parsing, but got: {s}", .{err.desc});
            return error.Test;
        },
    }
}

pub fn testParse(comptime def: anytype, str: []const u8) ReturnType(def.parse) {
    var parser = p.Parser.init(str);

    return def.parse(&parser);
}

pub fn derefParserElem(comptime P: type) type {
    return switch (@typeInfo(P)) {
        .pointer => |info| info.child,
        else => P,
    };
}

pub fn ReturnType(comptime f: anytype) type {
    const T = @TypeOf(f);
    return switch (@typeInfo(T)) {
        .@"fn" => |info| info.return_type.?,
        .pointer => |info| @typeInfo(info.child).@"fn".return_type.?,
        else => @compileError("expected fn or *const fn, got " ++ @typeName(T)),
    };
}

pub fn InnerReturnType(comptime f: anytype) type {
    return @TypeOf(f.*).T_;
}
