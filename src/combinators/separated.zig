const parser = @import("parser.zig");
const utils = @import("utils.zig");
const litteral = @import("litteral.zig");
const std = @import("std");

pub fn separated(comptime item: anytype, comptime sep: anytype) parser.Parser([]utils.TypeOfParser(item).OutputType) {
    const T = utils.TypeOfParser(item).OutputType;
    return .{
        .parse = struct {
            fn parse(alloc: std.mem.Allocator, p: *parser.State) parser.Result([]T) {
                var list: std.ArrayListUnmanaged(T) = .empty;

                const before_first = p.checkpoint();
                switch (item.parse(alloc, p)) {
                    .ok => |first| {
                        list.append(alloc, first) catch return parser.AllocErr([]T);
                        while (true) {
                            const before_sep = p.checkpoint();
                            switch (sep.parse(alloc, p)) {
                                .ok => {},
                                .err => {
                                    p.restore(before_sep);
                                    break;
                                },
                            }
                            const before_next = p.checkpoint();
                            switch (item.parse(alloc, p)) {
                                .ok => |v| list.append(alloc, v) catch return parser.AllocErr([]T),
                                .err => {
                                    p.restore(before_next);
                                    break;
                                },
                            }
                        }
                    },
                    .err => p.restore(before_first),
                }
                return .{ .ok = list.toOwnedSlice(alloc) catch return parser.AllocErr([]T) };
            }
        }.parse,
    };
}
