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

albedo: Color3,

pub fn scatter(self: @This(), r_in: Ray, record: HitRecord) ?common.ScatterResult {
    const reflected = Vec3.reflect(r_in.direction, record.normal);

    return .{
        .scatteredRay = .new(record.p, reflected),
        .attenuation = self.albedo,
    };
}
