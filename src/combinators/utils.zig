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
            std.log.err("Expected OK parsing, but got: {s}", .{err.desc});
            return error.Test;
        },
    }
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

/// Builder-style test result that captures both the parse result and the final parser state.
/// Errors are accumulated internally so every assertion method returns `Self` for chaining.
pub fn TestParseResult(comptime T: type) type {
    return struct {
        const Self = @This();

        result: parser.Result(T),
        state: parser.State,
        err: ?[]const u8,

        fn fail(self: *Self, msg: []const u8) void {
            if (self.err == null) self.err = msg;
        }

        /// Assert the parse succeeded.
        pub fn expectOk(self: *Self) *Self {
            if (self.result == .err) {
                self.fail("expected OK parsing, but got error");
            }
            return self;
        }

        /// Assert the parse failed.
        pub fn expectErr(self: *Self) *Self {
            if (self.result == .ok) {
                self.fail("expected error parsing, but got OK");
            }
            return self;
        }

        /// Assert the parsed ok value equals `expected`.
        pub fn expectValue(self: *Self, expected: T) *Self {
            if (self.result == .err) {
                self.fail("expected OK parsing for value comparison, but got error");
            } else {
                std.testing.expectEqualDeep(expected, self.result.ok) catch |e| {
                    self.fail(@errorName(e));
                };
            }
            return self;
        }

        /// Assert the remaining unconsumed input equals `expected`.
        pub fn expectRest(self: *Self, expected: []const u8) *Self {
            std.testing.expectEqualStrings(expected, self.state.rest()) catch |e| {
                self.fail(@errorName(e));
            };
            return self;
        }

        /// Assert the parser is at EOF.
        pub fn expectEof(self: *Self) *Self {
            std.testing.expect(self.state.isEof()) catch |e| {
                self.fail(@errorName(e));
            };
            return self;
        }

        /// Assert the error code equals `expected`.
        pub fn expectErrorCode(self: *Self, expected: parser.ErrorCode) *Self {
            if (self.result == .ok) {
                self.fail("expected error for code comparison, but got OK");
            } else {
                std.testing.expectEqual(expected, self.result.err.code) catch |e| {
                    self.fail(@errorName(e));
                };
            }
            return self;
        }

        /// Assert the error's `expected` field equals `expected`.
        pub fn expectExpected(self: *Self, expected: ?[]const u8) *Self {
            if (self.result == .ok) {
                self.fail("expected error for expected comparison, but got OK");
            } else {
                std.testing.expectEqualStrings(expected orelse "", self.result.err.expected orelse "") catch |e| {
                    self.fail(@errorName(e));
                };
            }
            return self;
        }

        /// If any assertion failed, return an error; otherwise return the final result.
        pub fn finish(self: *Self) !void {
            if (self.err) |msg| {
                std.log.err("TestParseResult assertion failed: {s}", .{msg});
                return error.TestAssertionFailed;
            }
        }
    };
}

/// Parse `input` with `def`, returning a builder-style `TestParseResult` for chained assertions.
pub fn testParse(comptime def: anytype, input: []const u8) TestParseResult(TypeOfParser(def).OutputType) {
    var state = parser.State.init(input);
    const result = def.parse(&state);
    return .{
        .result = result,
        .state = state,
        .err = null,
    };
}
