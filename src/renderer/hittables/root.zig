const common = @import("common.zig");
pub const Sphere = @import("Sphere.zig");
pub const Quad = @import("Quad.zig");

const renderer = @import("../root.zig");
const Ray = renderer.math.Ray;
const Interval = renderer.math.Interval;

pub const HitRecord = common.HitRecord;

const std = @import("std");

pub const Hittable = union(enum) {
    sphere: Sphere,
    quad: Quad,

    pub fn from(value: anytype) Hittable {
        const fields = @typeInfo(Hittable).@"union".fields;
        inline for (fields) |field| {
            if (field.type == @TypeOf(value)) {
                return @unionInit(Hittable, field.name, value);
            }
        }
        @compileError("Type " ++ @typeName(@TypeOf(value)) ++ " is not a Hittable variant");
    }

    pub fn hit(self: @This(), r: Ray, ray_t: Interval) ?HitRecord {
        return switch (self) {
            inline else => |h| h.hit(r, ray_t),
        };
    }
};

pub const HittableList = struct {
    items: std.ArrayList(Hittable),
    alloc: std.mem.Allocator,

    pub fn new(alloc: std.mem.Allocator) @This() {
        return .{ .items = .empty, .alloc = alloc };
    }

    pub fn add(self: *@This(), hittable: Hittable) !void {
        try self.items.append(self.alloc, hittable);
    }

    pub fn hit(self: @This(), r: Ray, ray_t: Interval) ?HitRecord {
        var temp: ?HitRecord = null;
        var closestSoFar = ray_t.max;

        for (self.items.items) |item| {
            if (item.hit(r, .{ .min = ray_t.min, .max = closestSoFar })) |record| {
                temp = record;
                closestSoFar = record.t;
            }
        }

        return temp;
    }
};
