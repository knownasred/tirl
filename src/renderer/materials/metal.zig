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
fuzz: f32,

pub fn scatter(self: @This(), r_in: Ray, record: HitRecord) ?common.ScatterResult {
    var reflected = Vec3.reflect(r_in.direction, record.normal);
    reflected = reflected.unit()
        .add(Vec3.randomUnit().mul_s(self.fuzz));
    const scatteredRay: Ray = .new(record.p, reflected);

    if (Vec3.dot(scatteredRay.direction, record.normal) > 0) {
        return .{
            .scatteredRay = scatteredRay,
            .attenuation = self.albedo,
        };
    } else {
        return null;
    }
}
