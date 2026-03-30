pub const Parser = @import("parser.zig").Parser;
const std = @import("std");
const Checkpoint = Parser.Checkpoint;
const combinators = @This();
const u = @import("utils.zig");

fn map(comptime parser: anytype, comptime f: anytype) ParserElem(u.ReturnType(f)) {
    const Elem = u.derefParserElem(@TypeOf(parser));
    const T = Elem.T_;
    comptime {
        const info = @typeInfo(@TypeOf(f)).@"fn";
        if (info.params[0].type.? != T) @compileError("expected fn(T), got wrong param type");
    }
    return .{
        .parse = struct {
            fn parse(p: *Parser) ParserResult(u.ReturnType(f)) {
                return switch (parser.parse(p)) {
                    .ok => |val| .{ .ok = f(val) },
                    .err => |err| .{ .err = err },
                };
            }
        }.parse,
    };
}

pub fn notEmpty(comptime self: anytype) @TypeOf(self.*) {
    return .{
        .parse = struct {
            fn parse(pa: *Parser) ParserResult(u.InnerReturnType(self)) {
                // Consider the value, even if all of them are silenced
                const cp = pa.checkpoint();

                const result = self.parse(pa);

                switch (result) {
                    .ok => |val| {
                        if (val.len > 0) {
                            return Ok(u.InnerReturnType(self), val);
                        } else {
                            pa.restore(cp);
                            return Err(u.InnerReturnType(self), ErrorCode.UnexpectedToken, "Expected token", cp);
                        }
                    },
                    .err => {
                        pa.restore(cp);
                        return result;
                    },
                }
            }
        }.parse,
    };
}

pub const ErrorCode = enum { UnexpectedToken, UnexpectedEOF, ReadError, ValueTooBig };

pub const Error = struct { code: ErrorCode, desc: []const u8, location: ?Checkpoint };

pub fn Ok(comptime T: type, value: T) ParserResult(T) {
    return .{ .ok = value };
}

pub fn Err(comptime T: type, errCode: ErrorCode, desc: []const u8, loc: Checkpoint) ParserResult(T) {
    return .{
        .err = .{ .code = errCode, .desc = desc, .location = loc },
    };
}

pub fn AllocErr(comptime T: type) ParserResult(T) {
    return .{ .err = .{ .code = ErrorCode.ReadError, .desc = "Error occurred while parsing the document", .location = null } };
}

pub fn ParserResult(comptime T: type) type {
    return union(enum) { ok: T, err: Error };
}

pub fn ParserElem(comptime T: type) type {
    return struct {
        pub const T_ = T;
        parse: *const fn (p: *Parser) ParserResult(T),

        // UFCS aliases — these let you write `literal("x").map(f)` as chained calls
        pub const map = combinators.map;
        pub const notEmpty = combinators.notEmpty;
    };
}
