const common = @import("common.zig");
const Sphere = @import("Sphere.zig");

const renderer = @import("../root.zig");
const Ray = renderer.math.Ray;

pub const HitRecord = common.HitRecord;

const std = @import("std");

pub const Hittable = union(enum) {
    sphere: Sphere,

    pub fn hit(self: @This(), r: Ray, t_min: f64, t_max: f64) ?HitRecord {
        return switch (self) {
            inline else => |h| h.hit(r, t_min, t_max),
        };
    }
};

pub const HittableList = struct {
    items: std.ArrayList(Hittable),
    alloc: std.mem.Allocator,

    pub fn new(alloc: std.mem.Allocator) @This() {
        return .{ .items = .empty, .alloc = alloc };
    }

    pub fn addSphere(self: *@This(), sphere: Sphere) void {
        self.items.append(self.alloc, .{ .sphere = sphere }) catch unreachable;
    }

    pub fn hit(self: @This(), r: Ray, t_min: f64, t_max: f64) ?HitRecord {
        var temp: ?HitRecord = null;
        var closestSoFar = t_max;

        for (self.items.items) |item| {
            if (item.hit(r, t_min, closestSoFar)) |record| {
                temp = record;
                closestSoFar = record.t;
            }
        }

        return temp;
    }
};
