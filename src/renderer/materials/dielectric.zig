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

const std = @import("std");


/// Refractive index in vaccum or air, or the ratio of the material's refractive index over the refractive
/// index of the enclosing media.
refractionIndex: f32,

const std_lib = @import("std");

pub fn scatter(self: @This(), r_in: Ray, record: HitRecord, rng: std_lib.Random) ?common.ScatterResult {
    const ri = if (record.front_face) 1 / self.refractionIndex else self.refractionIndex;

    const unitDirection = r_in.direction.unit();
    const cosTheta = @min(Vec3.dot(unitDirection.negate(), record.normal), 1.0);
    const sinTheta = @sqrt(1 - cosTheta * cosTheta);

    const refracted =
        if (ri * sinTheta > 1.0 or reflectance(cosTheta, ri) > rng.float(f32))
            Vec3.reflect(unitDirection, record.normal)
        else
            Vec3.refract(unitDirection, record.normal, ri);

    return .{
        .attenuation = .new(1, 1, 1),
        .scatteredRay = .new(record.p, refracted),
    };
}

fn reflectance(cosine: f32, refractionIndex: f32) f32 {
    const r0 = (1 - refractionIndex) / (1 + refractionIndex);
    const r0sq = r0 * r0;

    return r0sq + (1 - r0sq) * std.math.pow(f32, 1 - cosine, 5);
}
