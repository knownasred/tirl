const renderer = @import("../root.zig");
const Point3 = renderer.math.Point3;
const Vec3 = renderer.math.Vec3;
const Ray = renderer.math.Ray;
const Interval = renderer.math.Interval;

const Material = @import("../materials/root.zig").Material;
const HitRecord = @import("root.zig").HitRecord;

q: Point3,
u: Vec3,
v: Vec3,
material: *const Material,

pub fn hit(self: @This(), ray: Ray, ray_t: Interval) ?HitRecord {
    const n = Vec3.cross(self.u, self.v);
    const normal = n.unit();
    const w = n.div_s(n.dot(n));
    const d = normal.dot(self.q.inner);

    const denom = normal.dot(ray.direction);
    if (@abs(denom) < 1e-8) return null;

    const t = (d - normal.dot(ray.origin.inner)) / denom;
    if (!ray_t.surrounds(t)) return null;

    const intersection = ray.at(t);
    const planar_hit = intersection.inner.sub(self.q.inner);
    const alpha = w.dot(Vec3.cross(planar_hit, self.v));
    const beta = w.dot(Vec3.cross(self.u, planar_hit));

    if (alpha < 0 or alpha > 1 or beta < 0 or beta > 1) return null;

    var result: HitRecord = .{
        .t = t,
        .p = intersection,
        .normal = normal,
        .front_face = false,
        .material = self.material,
    };
    result.setFaceNormal(ray, normal);

    return result;
}
