const renderer = @import("../root.zig");
const Material = @import("../materials/root.zig").Material;
const Image = renderer.Image;
const Color3 = renderer.math.Color3;
const Point3 = renderer.math.Point3;
const Vec3 = renderer.math.Vec3;
const Ray = renderer.math.Ray;
const toFloat = renderer.math.toFloat;
const toInt = renderer.math.toInt;

pub const HitRecord = struct {
    p: Point3,
    normal: Vec3,
    t: f32,
    front_face: bool,
    material: *const Material,

    pub fn setFaceNormal(self: *@This(), ray: Ray, outward_normal: Vec3) void {
        // Sets the hit record normal vector.
        // NOTE: the parameter `outward_normal` is assumed to have unit length.
        self.front_face = ray.direction.dot(outward_normal) < 0;

        if (self.front_face) {
            self.normal = outward_normal;
        } else {
            self.normal = outward_normal.negate();
        }
    }
};
