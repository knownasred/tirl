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

pub fn rayColor(ray: Ray) Color3 {
    if (hitSphere(Point3.new(0, 0, -1), 0.5, ray)) {
        return Color3.new(1, 0, 0);
    }

    const unit_direction = ray.direction.unit();
    // Lerp, with a being the progression
    const a = 0.5 * (unit_direction.getY() + 1.0);
    const start = Color3.new(1.0, 1.0, 1.0);
    const end = Color3.new(0.5, 0.7, 1.0);

    return Color3.from(start.inner.mul_s(1.0 - a)
        .add(end.inner.mul_s(a)));
}

pub fn hitSphere(center: Point3, radius: f32, ray: Ray) bool {
    const oc = center.inner.sub(ray.origin.inner);
    const a = ray.direction.dot(ray.direction);
    const b = -2 * ray.direction.dot(oc);
    const c = oc.dot(oc) - radius * radius;

    const discriminant = b * b - 4 * a * c;

    return (discriminant >= 0);
}

pub fn render(alloc: std.mem.Allocator, progress: *Progress) !Image {
    const aspect_ratio = 16.0 / 9.0;
    const image_width = 400;

    const image_height: usize = @max(
        toInt(toFloat(image_width) / aspect_ratio),
        1,
    );

    progress.setTotal(image_height);

    var image = try Image.create(alloc, image_width, image_height);

    const focal_length = 1.0;
    const viewport_height = 2.0;
    const viewport_width = viewport_height * (toFloat(image.width) / toFloat(image.height));
    const camera_center = Point3.new(0, 0, 0);

    // Note to self on viewport:
    // - V_u (viewport U) goes from the left to the right
    // - V_v (viewport V) goes from the top to the bottom
    const viewport_u = Vec3.new(viewport_width, 0, 0);
    const viewport_v = Vec3.new(0, -viewport_height, 0);

    const pixel_delta_u = viewport_u.div_s(image_width);
    const pixel_delta_v = viewport_v.div_s(image_height);

    const viewport_upper_left = camera_center.inner
        .sub(Vec3.new(0, 0, focal_length))
        .sub(viewport_u.div_s(2))
        .sub(viewport_v.div_s(2));

    const pixel00_loc = viewport_upper_left.add(pixel_delta_u.add(pixel_delta_v).mul_s(0.5));

    for (0..image.height) |j| {
        for (0..image.width) |i| {
            const pixel_center = pixel00_loc
                .add(pixel_delta_u.mul_s(toFloat(i)))
                .add(pixel_delta_v.mul_s(toFloat(j)));

            const ray = Ray.new(camera_center, pixel_center);

            image.set(j, i, rayColor(ray));
        }

        progress.increment(1);
    }

    return image;
}
