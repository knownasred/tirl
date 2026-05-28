const common = @import("common.zig");
const Sphere = @import("Sphere.zig");

const renderer = @import("../root.zig");
const Ray = renderer.math.Ray;
const Interval = renderer.math.Interval;

pub const HitRecord = common.HitRecord;

const std = @import("std");

pub const Hittable = union(enum) {
    sphere: Sphere,

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

    pub fn addSphere(self: *@This(), sphere: Sphere) !void {
        try self.items.append(self.alloc, .{ .sphere = sphere });
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
