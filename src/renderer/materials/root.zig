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
const Lambertian = @import("lambertian.zig");
const Metal = @import("metal.zig");
const Dielectric = @import("dielectric.zig");

pub const Material = union(enum) {
    Lambertian: Lambertian,
    Metal: Metal,
    Dielectric: Dielectric,
    pub fn scatter(self: @This(), ray: Ray, record: HitRecord) ?common.ScatterResult {
        return switch (self) {
            inline else => |t| t.scatter(ray, record),
        };
    }

    pub fn makeLambertian(albedo: Color3) Material {
        return .{
            .Lambertian = .{ .albedo = albedo },
        };
    }

    pub fn makeMetal(albedo: Color3, fuzz: f32) Material {
        return .{
            .Metal = .{ .albedo = albedo, .fuzz = fuzz },
        };
    }

    pub fn makeDielectric(ri: f32) Material {
        return .{
            .Dielectric = .{ .refractionIndex = ri },
        };
    }
};
