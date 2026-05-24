const renderer = @import("../root.zig");
const Image = renderer.Image;
const Color3 = renderer.math.Color3;
const Point3 = renderer.math.Point3;
const Vec3 = renderer.math.Vec3;
const Ray = renderer.math.Ray;
const toFloat = renderer.math.toFloat;
const toInt = renderer.math.toInt;

const HitRecord = @import("root.zig").HitRecord;

center: Point3,
radius: f32,

pub fn create(center: Point3, radius: f32) @This() {
    return .{
        .center = center,
        .radius = radius,
    };
}

pub fn hit(self: @This(), ray: Ray, t_min: f64, t_max: f64) ?HitRecord {
    const oc = self.center.inner.sub(ray.origin.inner);
    const a = ray.direction.length_squared();
    const h = ray.direction.dot(oc);
    const c = oc.length_squared() - self.radius * self.radius;

    const discriminant = h * h - a * c;

    if (discriminant < 0) {
        return null;
    }

    const sqrt_d = @sqrt(discriminant);

    var root = (h - sqrt_d) / a;
    if (root <= t_min or t_max <= root) {
        root = (h + sqrt_d) / a;
        if (root <= t_min or t_max <= root)
            return null;
    }

    const p = ray.at(root);

    var result: HitRecord = .{
        .t = root,
        .p = p,
        .normal = p.inner
            .sub(self.center.inner)
            .div_s(self.radius),
        .front_face = false,
    };

    const outward_normal = p.inner
        .sub(self.center.inner)
        .div_s(self.radius);
    result.setFaceNormal(ray, outward_normal);

    return result;
}
