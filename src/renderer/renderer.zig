const renderer = @import("root.zig");
const Image = renderer.Image;
const Color3 = renderer.math.Color3;
const Point3 = renderer.math.Point3;
const Vec3 = renderer.math.Vec3;
const Ray = renderer.math.Ray;
const toFloat = renderer.math.toFloat;
const toInt = renderer.math.toInt;

const std = @import("std");
// Simplify the setup
const Progress = @import("../tui/root.zig").Progress;

const hittables = @import("hittables/root.zig");
const constants = @import("constants.zig");
const Camera = @import("camera.zig");
pub fn rayColor(ray: Ray, world: *const hittables.HittableList) Color3 {
    if (world.hit(ray, .{ .min = 0, .max = constants.infinity })) |t| {
        return Color3.from(
            t.normal
                .add(Vec3.new(1, 1, 1))
                .mul_s(0.5),
        );
    }

    const unit_direction = ray.direction.unit();
    // Lerp, with a being the progression
    const a = 0.5 * (unit_direction.getY() + 1.0);
    const start = Color3.new(1.0, 1.0, 1.0);
    const end = Color3.new(0.5, 0.7, 1.0);

    return Color3.from(start.inner.mul_s(1.0 - a)
        .add(end.inner.mul_s(a)));
}

pub fn render(alloc: std.mem.Allocator, progress: *Progress) !Image {
    // World
    var world = hittables.HittableList.new(alloc);

    world.addSphere(.{ .center = Point3.new(0, 0, -1), .radius = 0.5 });
    world.addSphere(.{ .center = Point3.new(0, -100.5, -1), .radius = 100 });

    const camera: Camera = .{
        .aspectRatio = 16.0 / 9.0,
        .imageWidth = 400,
    };

    return try camera.render(alloc, progress, &world);
}
