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

const std = @import("std");

pub fn scatter(self: @This(), _: Ray, record: HitRecord, rng: std.Random) ?common.ScatterResult {
    var scatterDirection = record.normal.add(Vec3.randomUnit(rng));

    if (scatterDirection.isNearZero()) {
        scatterDirection = record.normal;
    }

    return .{
        .attenuation = self.albedo,
        .scatteredRay = .new(record.p, scatterDirection),
    };
}
