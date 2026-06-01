const std = @import("std");
const ast = @import("../ast/root.zig");
const renderer = @import("../renderer/root.zig");

const Block = ast.block.Block;
const Value = ast.block.Value;
const Point3 = renderer.math.Point3;
const Color3 = renderer.math.Color3;
const Vec3 = renderer.math.Vec3;

pub const InterpretError = error{
    MissingAttr,
    InvalidValue,
    InvalidCall,
    UnresolvedRef,
    MissingCamera,
    OutOfMemory,
};

fn isOptional(comptime T: type) bool {
    return @typeInfo(T) == .optional;
}

fn isConstPtr(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == .pointer and info.pointer.size == .one and info.pointer.is_const;
}

fn isIgnored(comptime T: type, comptime field_name: []const u8) bool {
    if (@hasDecl(T, "_ignore")) {
        for (T._ignore) |name| {
            if (std.mem.eql(u8, name, field_name)) return true;
        }
    }
    return false;
}

pub fn parseBlock(comptime T: type, block: Block, resolver: anytype) InterpretError!T {
    const info = @typeInfo(T).@"struct";
    var result: T = undefined;

    inline for (info.fields) |field| {
        if (comptime isIgnored(T, field.name)) {
            @field(result, field.name) = comptime field.defaultValue() orelse
                @compileError("ignored field '" ++ field.name ++ "' must have a default value");
            continue;
        }

        if (getAttr(block, field.name)) |value| {
            @field(result, field.name) = try parseValue(field.type, value, resolver);
        } else if (comptime field.defaultValue()) |default| {
            @field(result, field.name) = default;
        } else if (comptime isOptional(field.type)) {
            @field(result, field.name) = null;
        } else {
            return error.MissingAttr;
        }
    }

    return result;
}

fn parseValue(comptime T: type, value: Value, resolver: anytype) InterpretError!T {
    if (comptime isOptional(T)) {
        const Child = std.meta.Child(T);
        return try parseValue(Child, value, resolver);
    }
    if (comptime isConstPtr(T)) {
        const Child = @typeInfo(T).pointer.child;
        return switch (value) {
            .reference => |ref| resolver.resolve(Child, ref.value),
            else => error.InvalidValue,
        };
    }
    if (T == f32) return toF32(value);
    if (T == usize) return toUsize(value);
    if (T == Point3) return toPoint3(value);
    if (T == Color3) return toColor3(value);
    if (T == Vec3) return toVec3(value);
    if (comptime @hasDecl(T, "fromValue")) return T.fromValue(value);
    @compileError("Unsupported field type in parseBlock: " ++ @typeName(T));
}

fn getAttr(block: Block, name: []const u8) ?Value {
    for (block.body) |item| {
        switch (item) {
            .attribute => |attr| {
                if (std.mem.eql(u8, attr.name.value, name)) return attr.value;
            },
            .block => {},
        }
    }
    return null;
}

fn extractF32x3(value: Value, name: []const u8) InterpretError!struct { f32, f32, f32 } {
    switch (value) {
        .call => |call| {
            if (call.args.len != 3 or !std.mem.eql(u8, call.name.value, name)) return error.InvalidCall;

            return .{
                @as(f32, @floatCast(call.args[0].number)),
                @as(f32, @floatCast(call.args[1].number)),
                @as(f32, @floatCast(call.args[2].number)),
            };
        },
        else => return error.InvalidValue,
    }
}

fn toPoint3(value: Value) InterpretError!Point3 {
    const v = try extractF32x3(value, "Point3");
    return Point3.new(v[0], v[1], v[2]);
}

fn toColor3(value: Value) InterpretError!Color3 {
    const v = try extractF32x3(value, "Color3");
    return Color3.new(v[0], v[1], v[2]);
}

fn toVec3(value: Value) InterpretError!Vec3 {
    const v = try extractF32x3(value, "Vec3");
    return Vec3.new(v[0], v[1], v[2]);
}

fn toF32(value: Value) InterpretError!f32 {
    switch (value) {
        .number => |n| return @floatCast(n),
        else => return error.InvalidValue,
    }
}

fn toUsize(value: Value) InterpretError!usize {
    switch (value) {
        .number => |n| return @intFromFloat(n),
        else => return error.InvalidValue,
    }
}
