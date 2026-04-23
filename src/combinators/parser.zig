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

/// Wrap a parser so that when it fails the error carries `name` as its
/// `expected` field.  This lets higher-level callers report *what* was
/// being parsed (e.g. "expected a component type name").
pub fn label(comptime parser: anytype, comptime name: []const u8) utils.TypeOfParser(parser) {
    const P = utils.TypeOfParser(parser);
    return .{
        .parse = struct {
            fn parse(p: *State) P.ResultType {
                return switch (parser.parse(p)) {
                    .ok => |val| .{ .ok = val },
                    .err => |err| .{ .err = .{
                        .code = err.code,
                        .desc = err.desc,
                        .expected = name,
                        .location = err.location,
                    } },
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
                            return Self.ResultType{ .err = .{
                                .code = ErrorCode.UnexpectedToken,
                                .desc = "Expected token",
                                .expected = null,
                                .location = cp,
                            } };
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

pub const Error = struct {
    code: ErrorCode,
    desc: []const u8,
    expected: ?[]const u8,
    location: ?Checkpoint,

    pub fn display(self: Error, writer: anytype) !void {
        const loc = self.location orelse {
            try writer.print("Error: {s}\n", .{self.desc});
            return;
        };
        try writer.print("Error at {d}:{d}: ", .{ loc.line + 1, loc.col + 1 });
        if (self.expected) |exp| {
            try writer.print("expected {s}, but ", .{exp});
        }
        try writer.print("{s}\n", .{self.desc});
    }
};

pub fn Ok(comptime T: type, value: T) Result(T) {
    return .{ .ok = value };
}

pub fn Err(comptime T: type, errCode: ErrorCode, desc: []const u8, loc: Checkpoint) Result(T) {
    return .{
        .err = .{ .code = errCode, .desc = desc, .expected = null, .location = loc },
    };
}

pub fn AllocErr(comptime T: type) Result(T) {
    return .{ .err = .{ .code = ErrorCode.ReadError, .desc = "Error occurred while parsing the document", .expected = null, .location = null } };
}

pub fn Result(comptime T: type) type {
    return union(enum) { ok: T, err: Error };
}

// ─── Tests for label and display ────────────────────────────────────────────

test "label sets expected on error" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime lit.literal("hello").label("a greeting");
    var r = t.testParse(combinator, "world");
    try r.expectErr().expectExpected("a greeting").finish();
}

test "label preserves ok result" {
    const t = @import("utils.zig");
    const lit = @import("litteral.zig");

    const combinator = comptime lit.literal("hello").label("a greeting");
    var r = t.testParse(combinator, "hello");
    try r.expectOk().expectRest("").finish();
}

test "Error.display formats line and col" {
    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    const Writer = struct {
        buf: []u8,
        pos: *usize,
        pub fn writeAll(self: @This(), bytes: []const u8) !void {
            @memcpy(self.buf[self.pos.*..self.pos.* + bytes.len], bytes);
            self.pos.* += bytes.len;
        }
        pub fn print(self: @This(), comptime fmt: []const u8, args: anytype) !void {
            const s = std.fmt.bufPrint(self.buf[self.pos.*..], fmt, args) catch return error.NoSpaceLeft;
            self.pos.* += s.len;
        }
    };
    const writer = Writer{ .buf = &buf, .pos = &pos };

    const err = Error{
        .code = .UnexpectedToken,
        .desc = "Unexpected token",
        .expected = "an identifier",
        .location = .{ .pos = 5, .line = 2, .col = 3 },
    };
    try err.display(writer);
    try std.testing.expectEqualStrings("Error at 3:4: expected an identifier, but Unexpected token\n", buf[0..pos]);
}

test "Error.display without expected" {
    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    const Writer = struct {
        buf: []u8,
        pos: *usize,
        pub fn writeAll(self: @This(), bytes: []const u8) !void {
            @memcpy(self.buf[self.pos.*..self.pos.* + bytes.len], bytes);
            self.pos.* += bytes.len;
        }
        pub fn print(self: @This(), comptime fmt: []const u8, args: anytype) !void {
            const s = std.fmt.bufPrint(self.buf[self.pos.*..], fmt, args) catch return error.NoSpaceLeft;
            self.pos.* += s.len;
        }
    };
    const writer = Writer{ .buf = &buf, .pos = &pos };

    const err = Error{
        .code = .UnexpectedEOF,
        .desc = "Unexpected EOF",
        .expected = null,
        .location = .{ .pos = 0, .line = 0, .col = 0 },
    };
    try err.display(writer);
    try std.testing.expectEqualStrings("Error at 1:1: Unexpected EOF\n", buf[0..pos]);
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
        pub const label = combinators.label;
    };
}
