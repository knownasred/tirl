const renderer = @import("../root.zig");
const Image = renderer.Image;
const Color3 = renderer.math.Color3;
const Point3 = renderer.math.Point3;
const Vec3 = renderer.math.Vec3;
const Ray = renderer.math.Ray;
const Interval = renderer.math.Interval;
const toFloat = renderer.math.toFloat;
const toInt = renderer.math.toInt;

const Material = @import("../materials/root.zig").Material;
const HitRecord = @import("root.zig").HitRecord;

position: Point3,
radius: f32,
material: *const Material,

pub fn hit(self: @This(), ray: Ray, ray_t: Interval) ?HitRecord {
    const oc = self.position.inner.sub(ray.origin.inner);
    const a = ray.direction.length_squared();
    const h = ray.direction.dot(oc);
    const c = oc.length_squared() - self.radius * self.radius;

    const discriminant = h * h - a * c;

    if (discriminant < 0) {
        return null;
    }

    const sqrt_d = @sqrt(discriminant);

    var root = (h - sqrt_d) / a;
    if (!ray_t.surrounds(root)) {
        root = (h + sqrt_d) / a;
        if (!ray_t.surrounds(root))
            return null;
    }

    const p = ray.at(root);

    var result: HitRecord = .{
        .t = root,
        .p = p,
        .normal = p.inner
            .sub(self.position.inner)
            .div_s(self.radius),
        .front_face = false,
        .material = self.material,
    };

    const outward_normal = p.inner
        .sub(self.position.inner)
        .div_s(self.radius);
    result.setFaceNormal(ray, outward_normal);

    return result;
}
