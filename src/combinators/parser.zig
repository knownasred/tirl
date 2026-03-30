const std = @import("std");

pub const Parser = struct {
    /// data contains the entire raw file.
    ///
    /// While this is not optimal, it simplifies the difficulty of the implementation by a lot.
    /// If streaming ever becomes a requirement
    /// (which should not be, unless we embed the assets directly in the scene definition),
    /// this can be revisited.
    data: []const u8,

    pos: usize,
    line: usize,
    col: usize,

    pub fn init(data: []const u8) Parser {
        return .{
            .data = data,
            .pos = 0,
            .line = 0,
            .col = 0,
        };
    }

    /// Read an entire file into memory and create a Parser over it.
    /// The caller owns the returned Parser and must call `deinit` to free the data.
    pub fn fromFile(alloc: std.mem.Allocator, path: []const u8) !Parser {
        const data = try std.fs.cwd().readFileAlloc(alloc, path, std.math.maxInt(usize));
        return .{
            .data = data,
            .pos = 0,
            .line = 0,
            .col = 0,
        };
    }

    /// Free the file data allocated by `fromFile`.
    pub fn deinit(self: *Parser, alloc: std.mem.Allocator) void {
        alloc.free(self.data);
        self.* = undefined;
    }

    pub const Checkpoint = struct { pos: usize, line: usize, col: usize };

    /// Peek at the next `n` bytes without consuming them.
    /// Returns null if fewer than `n` bytes remain.
    pub fn peek(self: *const Parser, n: usize) ?[]const u8 {
        if (self.pos + n > self.data.len) return null;
        return self.data[self.pos..][0..n];
    }

    /// Return all remaining unconsumed input.
    pub fn rest(self: *const Parser) []const u8 {
        return self.data[self.pos..];
    }

    /// Advance the position by `n` bytes, updating line/col tracking.
    pub fn advance(self: *Parser, n: usize) void {
        const slice = self.data[self.pos..][0..n];
        const newlines = std.mem.count(u8, slice, "\n");
        if (newlines > 0) {
            self.line += newlines;
            self.col = n - (std.mem.lastIndexOfScalar(u8, slice, '\n').? + 1);
        } else {
            self.col += n;
        }
        self.pos += n;
    }

    /// Save the current parser state for later rollback.
    pub fn checkpoint(self: *const Parser) Checkpoint {
        return .{ .pos = self.pos, .line = self.line, .col = self.col };
    }

    /// Restore parser state to a previously saved checkpoint.
    pub fn restore(self: *Parser, cp: Checkpoint) void {
        self.pos = cp.pos;
        self.line = cp.line;
        self.col = cp.col;
    }

    /// Returns true if all input has been consumed.
    pub fn isEof(self: *const Parser) bool {
        return self.pos >= self.data.len;
    }
};
