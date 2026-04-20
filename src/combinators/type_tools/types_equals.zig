const std = @import("std");

pub fn assertTypesMatch(comptime A: type, comptime B: type) void {
    comptime checkTypes(A, B, "root");
}

fn fail(comptime fmt: []const u8, comptime args: anytype) noreturn {
    @compileError(std.fmt.comptimePrint(fmt, args));
}

fn checkTypes(comptime A: type, comptime B: type, comptime path: []const u8) void {
    if (A == B) return;

    const ia = @typeInfo(A);
    const ib = @typeInfo(B);
    const tag_a = std.meta.activeTag(ia);
    const tag_b = std.meta.activeTag(ib);
    if (tag_a != tag_b) fail(
        "at `{s}`: kind — expected .{s} ({s}), got .{s} ({s})",
        .{ path, @tagName(tag_a), @typeName(A), @tagName(tag_b), @typeName(B) },
    );

    switch (ia) {
        .@"struct" => {
            const sa = ia.@"struct";
            const sb = ib.@"struct";
            if (sa.layout != sb.layout)
                fail("at `{s}`: struct layout — expected .{s}, got .{s}", .{ path, @tagName(sa.layout), @tagName(sb.layout) });
            if (sa.is_tuple != sb.is_tuple)
                fail("at `{s}`: is_tuple — expected {}, got {}", .{ path, sa.is_tuple, sb.is_tuple });
            if (sa.fields.len != sb.fields.len)
                fail("at `{s}`: field count — expected {d} [{s}], got {d} [{s}]", .{ path, sa.fields.len, joinNames(sa.fields), sb.fields.len, joinNames(sb.fields) });
            inline for (sa.fields, sb.fields) |fa, fb| {
                if (!std.mem.eql(u8, fa.name, fb.name))
                    fail("at `{s}`: field name — expected `{s}`, got `{s}`", .{ path, fa.name, fb.name });
                if (fa.is_comptime != fb.is_comptime)
                    fail("at `{s}.{s}`: is_comptime — expected {}, got {}", .{ path, fa.name, fa.is_comptime, fb.is_comptime });
                checkTypes(fa.type, fb.type, path ++ "." ++ fa.name);
            }
        },
        .@"enum" => {
            const ea = ia.@"enum";
            const eb = ib.@"enum";
            if (ea.is_exhaustive != eb.is_exhaustive)
                fail("at `{s}`: is_exhaustive — expected {}, got {}", .{ path, ea.is_exhaustive, eb.is_exhaustive });
            checkTypes(ea.tag_type, eb.tag_type, path ++ ".<tag>");
            if (ea.fields.len != eb.fields.len)
                fail("at `{s}`: variant count — expected {d} [{s}], got {d} [{s}]", .{ path, ea.fields.len, joinNames(ea.fields), eb.fields.len, joinNames(eb.fields) });
            inline for (ea.fields, eb.fields) |fa, fb| {
                if (!std.mem.eql(u8, fa.name, fb.name))
                    fail("at `{s}`: variant name — expected `{s}`, got `{s}`", .{ path, fa.name, fb.name });
                if (fa.value != fb.value)
                    fail("at `{s}.{s}`: value — expected {d}, got {d}", .{ path, fa.name, fa.value, fb.value });
            }
        },
        .@"union" => {
            const ua = ia.@"union";
            const ub = ib.@"union";
            if (ua.layout != ub.layout)
                fail("at `{s}`: union layout — expected .{s}, got .{s}", .{ path, @tagName(ua.layout), @tagName(ub.layout) });
            if ((ua.tag_type == null) != (ub.tag_type == null))
                fail("at `{s}`: tagged — expected {}, got {}", .{ path, ua.tag_type != null, ub.tag_type != null });
            if (ua.tag_type) |ta| checkTypes(ta, ub.tag_type.?, path ++ ".<tag>");
            if (ua.fields.len != ub.fields.len)
                fail("at `{s}`: variant count — expected {d}, got {d}", .{ path, ua.fields.len, ub.fields.len });
            inline for (ua.fields, ub.fields) |fa, fb| {
                if (!std.mem.eql(u8, fa.name, fb.name))
                    fail("at `{s}`: variant name — expected `{s}`, got `{s}`", .{ path, fa.name, fb.name });
                checkTypes(fa.type, fb.type, path ++ "." ++ fa.name);
            }
        },
        .pointer => {
            const pa = ia.pointer;
            const pb = ib.pointer;
            if (pa.size != pb.size)
                fail("at `{s}`: pointer size — expected .{s}, got .{s}", .{ path, @tagName(pa.size), @tagName(pb.size) });
            if (pa.is_const != pb.is_const)
                fail("at `{s}`: is_const — expected {}, got {}", .{ path, pa.is_const, pb.is_const });
            if (pa.is_volatile != pb.is_volatile)
                fail("at `{s}`: is_volatile — expected {}, got {}", .{ path, pa.is_volatile, pb.is_volatile });
            checkTypes(pa.child, pb.child, path ++ ".*");
        },
        .array => {
            const aa = ia.array;
            const ab = ib.array;
            if (aa.len != ab.len)
                fail("at `{s}`: array length — expected {d}, got {d}", .{ path, aa.len, ab.len });
            checkTypes(aa.child, ab.child, path ++ "[*]");
        },
        .optional => checkTypes(ia.optional.child, ib.optional.child, path ++ ".?"),
        .error_union => {
            checkTypes(ia.error_union.error_set, ib.error_union.error_set, path ++ ".<err>");
            checkTypes(ia.error_union.payload, ib.error_union.payload, path ++ ".<payload>");
        },
        else => fail(
            "at `{s}`: {s} != {s} (both .{s}, nominally distinct)",
            .{ path, @typeName(A), @typeName(B), @tagName(tag_a) },
        ),
    }
}

fn joinNames(comptime fields: anytype) []const u8 {
    comptime {
        var out: []const u8 = "";
        for (fields, 0..) |f, i| {
            if (i > 0) out = out ++ ", ";
            out = out ++ f.name;
        }
        return out;
    }
}
