pub const State = @import("state.zig").ParserState;
const std = @import("std");
const Checkpoint = State.Checkpoint;
const combinators = @This();
const utils = @import("utils.zig");

fn map(comptime parser: anytype, comptime f: anytype) Parser(utils.ReturnType(f)) {
    const T = utils.TypeOfParser(parser).OutputType;
    comptime {
        const info = @typeInfo(@TypeOf(f)).@"fn";
        if (info.params[0].type.? != T) @compileError("expected fn(T), got wrong param type");
    }
    return .{
        .parse = struct {
            fn parse(p: *State) Result(utils.ReturnType(f)) {
                return switch (parser.parse(p)) {
                    .ok => |val| .{ .ok = f(val) },
                    .err => |err| .{ .err = err },
                };
            }
        }.parse,
    };
}

pub fn notEmpty(comptime self: anytype) @TypeOf(self.*) {
    const Self = utils.TypeOfParser(self);
    return .{
        .parse = struct {
            fn parse(pa: *State) Self.ResultType {
                // Consider the value, even if all of them are silenced
                const cp = pa.checkpoint();

                const result = self.parse(pa);

                switch (result) {
                    .ok => |val| {
                        if (val.len > 0) {
                            return Ok(Self.OutputType, val);
                        } else {
                            pa.restore(cp);
                            return Err(Self.OutputType, ErrorCode.UnexpectedToken, "Expected token", cp);
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

pub fn Ok(comptime T: type, value: T) Result(T) {
    return .{ .ok = value };
}

pub fn Err(comptime T: type, errCode: ErrorCode, desc: []const u8, loc: Checkpoint) Result(T) {
    return .{
        .err = .{ .code = errCode, .desc = desc, .location = loc },
    };
}

pub fn AllocErr(comptime T: type) Result(T) {
    return .{ .err = .{ .code = ErrorCode.ReadError, .desc = "Error occurred while parsing the document", .location = null } };
}

pub fn Result(comptime T: type) type {
    return union(enum) { ok: T, err: Error };
}

pub fn Parser(comptime Ty: type) type {
    return struct {
        pub const OutputType = Ty;
        pub const ResultType = Result(Ty);

        pub fn Ok(val: OutputType) ResultType {
            return combinators.Ok(OutputType, val);
        }

        pub fn Err(errCode: ErrorCode, desc: []const u8, loc: Checkpoint) ResultType {
            return combinators.Err(OutputType, errCode, desc, loc);
        }

        parse: *const fn (p: *State) ResultType,

        // UFCS aliases — these let you write `literal("x").map(f)` as chained calls
        pub const map = combinators.map;
        pub const notEmpty = combinators.notEmpty;
    };
}
