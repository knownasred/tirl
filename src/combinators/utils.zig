const parser = @import("parser.zig");
const std = @import("std");
pub fn isErr(result: anytype) bool {
    return switch (result) {
        .err => true,
        .ok => false,
    };
}

pub fn isOk(result: anytype) bool {
    return !isErr(result);
}
pub fn isOkAndEq(result: anytype, val: anytype) !void {
    switch (result) {
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

pub fn testParse(comptime def: anytype, str: []const u8) TypeOfParser(def).ResultType {
    var state = parser.State.init(str);

    return def.parse(&state);
}

pub fn TypeOfParser(comptime p: anytype) type {
    return derefType(@TypeOf(p));
}

pub fn derefType(comptime P: type) type {
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
