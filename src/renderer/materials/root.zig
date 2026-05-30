const renderer = @import("../root.zig");
const Image = renderer.Image;
const HitRecord = renderer.hittables.HitRecord;
const Color3 = renderer.math.Color3;
const Point3 = renderer.math.Point3;
const Vec3 = renderer.math.Vec3;
const Ray = renderer.math.Ray;
const Interval = renderer.math.Interval;
const toFloat = renderer.math.toFloat;
const toInt = renderer.math.toInt;
const common = @import("common.zig");
pub const Lambertian = @import("lambertian.zig");
pub const Metal = @import("metal.zig");
pub const Dielectric = @import("dielectric.zig");

pub const Material = union(enum) {
    Lambertian: Lambertian,
    Metal: Metal,
    Dielectric: Dielectric,

    pub fn from(value: anytype) Material {
        const fields = @typeInfo(Material).@"union".fields;
        inline for (fields) |field| {
            if (field.type == @TypeOf(value)) {
                return @unionInit(Material, field.name, value);
            }
        }
        @compileError("Type " ++ @typeName(@TypeOf(value)) ++ " is not a Material variant");
    }

    const std = @import("std");

    pub fn scatter(self: @This(), ray: Ray, record: HitRecord, rng: std.Random) ?common.ScatterResult {
        return switch (self) {
            inline else => |t| t.scatter(ray, record, rng),
        };
    }
};
