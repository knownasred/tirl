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
            try writer.print("{s}: {s}\n", .{ attr.name.value, attr.value.value });
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
