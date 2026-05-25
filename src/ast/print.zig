const std = @import("std");
const block_mod = @import("block.zig");
const file_mod = @import("file.zig");

pub fn printFile(f: file_mod.File, writer: anytype) !void {
    for (f.items) |item| {
        try printItem(item, writer, 0);
    }
}

fn printItem(item: block_mod.Item, writer: anytype, depth: usize) !void {
    switch (item) {
        .attribute => |attr| {
            try writeIndent(writer, depth);
            try writer.print("{s}: ", .{attr.name.value});
            try printValue(attr.value, writer);
            try writer.writeAll("\n");
        },
        .block => |blk| {
            try writeIndent(writer, depth);
            try writer.print("{s} \"{s}\"\n", .{ blk.type_name.value, blk.label.value });
            for (blk.body) |child| {
                try printItem(child, writer, depth + 1);
            }
        },
    }
}

fn writeIndent(writer: anytype, depth: usize) !void {
    for (0..depth) |_| try writer.writeAll("  ");
}

fn printValue(value: block_mod.Value, writer: anytype) !void {
    switch (value) {
        .string => |s| try writer.print("{s}", .{s.value}),
        .boolean => |b| try writer.print("{}", .{b}),
        .number => |n| try writer.print("{d}", .{n}),
        .call => |c| {
            try writer.print("{s}(", .{c.name.value});
            for (c.args, 0..) |arg, i| {
                if (i > 0) try writer.writeAll(", ");
                try printValue(arg, writer);
            }
            try writer.writeAll(")");
        },
    }
}
