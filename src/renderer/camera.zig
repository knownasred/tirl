const hittables = @import("hittables/root.zig");
const constants = @import("constants.zig");
const renderer = @import("root.zig");
const AccumulationBuffer = renderer.AccumulationBuffer;
const Image = renderer.Image;
const Color3 = renderer.math.Color3;
const Point3 = renderer.math.Point3;
const Vec3 = renderer.math.Vec3;
const Ray = renderer.math.Ray;
const toFloat = renderer.math.toFloat;
const toInt = renderer.math.toInt;
const std = @import("std");

/// Rendered image width in pixel count
imageWidth: usize = 100,
/// Ratio of image width over height
aspectRatio: f32 = 16.0 / 9.0,
/// Count of random samples for each pixel
samplesPerPixel: usize = 100,
/// Maximum number of ray bounces into scene
maxDepth: usize = 10,

/// vfov is the vertical view angle (field of view)
vfov: f32 = 90,
/// Point camera is looking from
lookFrom: Point3 = .new(0, 0, 0),
/// Point camera is looking at
lookAt: Point3 = .new(0, 0, -1),
/// Camera relative "up" direction
vup: Point3 = .new(0, 1, 0),
/// Variation angle of rays through each pixel
defocusAngle: f32 = 0,
/// Distance from camera lookfrom point to plane of perfect focus
focusDistance: f32 = 10,

renderMode: RenderMode = .perPixel,

pub const RenderMode = enum { perPixel, progressive };
const Self = @This();

pub fn render(self: *const Self, alloc: std.mem.Allocator, progress: anytype, world: *const hittables.HittableList) !Image {
    return switch (self.renderMode) {
        .perPixel => self.renderPerPixel(alloc, progress, world),
        .progressive => self.renderProgressive(alloc, progress, world),
    };
}

fn renderPerPixel(self: *const Self, alloc: std.mem.Allocator, progress: anytype, world: *const hittables.HittableList) !Image {
    const state = self.initialize();
    progress.setTotal(state.imageHeight);

    var image = try Image.create(alloc, self.imageWidth, state.imageHeight);

    for (0..image.height) |j| {
        for (0..image.width) |i| {
            var pixel_color: Vec3 = .zero();

            for (0..self.samplesPerPixel) |s| {
                const ray = self.getRay(state, i, j);
                pixel_color = pixel_color.add(rayColor(ray, self.maxDepth, world).inner);
                progress.onPixel(j, i, s + 1, .from(pixel_color.mul_s(1.0 / toFloat(s + 1))));
            }

            image.set(j, i, .from(pixel_color.mul_s(state.pixelSampleScale)));
        }

        if (progress.increment(1)) return image;
    }

    return image;
}

fn renderProgressive(self: *const Self, alloc: std.mem.Allocator, progress: anytype, world: *const hittables.HittableList) !Image {
    const state = self.initialize();
    progress.setTotal(self.samplesPerPixel);

    var image = try Image.create(alloc, self.imageWidth, state.imageHeight);
    var accum = try AccumulationBuffer.create(alloc, self.imageWidth, state.imageHeight);

    for (0..self.samplesPerPixel) |s| {
        for (0..image.height) |j| {
            for (0..image.width) |i| {
                const ray = self.getRay(state, i, j);
                accum.accumulate(j, i, rayColor(ray, self.maxDepth, world).inner);
            }
        }

        accum.incrementSamples();

        for (0..image.height) |j| {
            for (0..image.width) |i| {
                const color = accum.averaged(j, i);
                image.set(j, i, color);
                progress.onPixel(j, i, s + 1, color);
            }
        }

        if (progress.increment(1)) return image;
    }

    return image;
}

fn getRay(self: @This(), state: CameraState, i: usize, j: usize) Ray {
    const offset = sampleSquare();
    const pixel_sample = state.pixel00Loc.inner
        .add(state.pixelDeltaU.mul_s(toFloat(i) + offset.getX()))
        .add(state.pixelDeltaV.mul_s(toFloat(j) + offset.getY()));

    const rayOrigin = if (self.defocusAngle <= 0) state.center.inner else defocusDiskSample(state);

    return .new(.from(rayOrigin), pixel_sample.sub(rayOrigin));
}

fn defocusDiskSample(state: CameraState) Vec3 {
    const p = Vec3.randomOnUnitDisk();

    return state.center.inner
        .add(state.defocusDiskU.mul_s(p.getX()))
        .add(state.defocusDiskV.mul_s(p.getY()));
}

fn sampleSquare() Vec3 {
    return .new(constants.randomDouble() - 0.5, constants.randomDouble() - 0.5, 0);
}

fn rayColor(ray: Ray, depth: usize, world: *const hittables.HittableList) Color3 {
    if (depth <= 0) {
        return .new(0, 0, 0);
    }

    if (world.hit(ray, .{ .min = 0.001, .max = constants.infinity })) |t| {
        if (t.material.scatter(ray, t)) |scattered| {
            return .from(
                scattered.attenuation.inner.mul(
                    rayColor(scattered.scatteredRay, depth - 1, world).inner,
                ),
            );
        }

        return .new(0, 0, 0);
    }

    const unit_direction = ray.direction.unit();
    // Lerp, with a being the progression
    const a = 0.5 * (unit_direction.getY() + 1.0);
    const start = Color3.new(1.0, 1.0, 1.0);
    const end = Color3.new(0.5, 0.7, 1.0);

    return Color3.from(start.inner.mul_s(1.0 - a)
        .add(end.inner.mul_s(a)));
}

const CameraState = struct {
    imageHeight: usize,
    center: Point3,
    pixel00Loc: Point3,
    pixelDeltaU: Vec3,
    pixelDeltaV: Vec3,
    pixelSampleScale: f32,
    u: Vec3,
    v: Vec3,
    w: Vec3,

    defocusDiskU: Vec3,
    defocusDiskV: Vec3,
};

fn initialize(self: *const Self) CameraState {
    const image_height: usize = @max(
        toInt(toFloat(self.imageWidth) / self.aspectRatio),
        1,
    );

    const theta = constants.deg_to_rad(self.vfov);
    const h = std.math.tan(theta / 2);

    const viewport_height = 2 * h * self.focusDistance;
    const viewport_width = viewport_height * (toFloat(self.imageWidth) / toFloat(image_height));
    const camera_center = self.lookFrom;

    const w = Vec3.unit(self.lookFrom.inner.sub(self.lookAt.inner));
    const u = Vec3.unit(Vec3.cross(self.vup.inner, w));
    const v = Vec3.cross(w, u);

    // Note to self on viewport:
    // - V_u (viewport U) goes from the left to the right
    // - V_v (viewport V) goes from the top to the bottom
    const viewport_u = u.mul_s(viewport_width);
    const viewport_v = v.negate().mul_s(viewport_height);

    const pixel_delta_u = viewport_u.div_s(toFloat(self.imageWidth));
    const pixel_delta_v = viewport_v.div_s(toFloat(image_height));

    const viewport_upper_left = camera_center.inner
        .sub(w.mul_s(self.focusDistance))
        .sub(viewport_u.div_s(2))
        .sub(viewport_v.div_s(2));

    const pixel00_loc = viewport_upper_left.add(pixel_delta_u.add(pixel_delta_v).mul_s(0.5));

    const defocus_radius = self.focusDistance * std.math.tan(constants.deg_to_rad(self.defocusAngle / 2));

    return .{
        .center = camera_center,
        .imageHeight = image_height,
        .pixel00Loc = Point3.from(pixel00_loc),
        .pixelDeltaU = pixel_delta_u,
        .pixelDeltaV = pixel_delta_v,
        .pixelSampleScale = 1.0 / toFloat(self.samplesPerPixel),
        .u = u,
        .v = v,
        .w = w,
        .defocusDiskU = u.mul_s(defocus_radius),
        .defocusDiskV = v.mul_s(defocus_radius),
    };
}
