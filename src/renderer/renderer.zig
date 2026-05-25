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

pub fn render(alloc: std.mem.Allocator, progress: *Progress) !Image {
    // World
    var world = hittables.HittableList.new(alloc);

    const materialGround = renderer.Material.makeLambertian(.new(0.8, 0.8, 0.0));
    const materialCenter = renderer.Material.makeLambertian(.new(0.1, 0.2, 0.5));
    const materialLeft = renderer.Material.makeMetal(.new(0.8, 0.8, 0.8));
    const materialRight = renderer.Material.makeLambertian(.new(0.8, 0.6, 0.2));

    world.addSphere(.{ .center = Point3.new(0, -100.5, -1), .radius = 100, .material = &materialGround });
    world.addSphere(.{ .center = Point3.new(0, 0, -1.2), .radius = 0.5, .material = &materialCenter });
    world.addSphere(.{ .center = Point3.new(-1, 0, -1), .radius = 0.5, .material = &materialLeft });
    world.addSphere(.{ .center = Point3.new(1, 0, -1), .radius = 0.5, .material = &materialRight });

    const camera: Camera = .{
        .aspectRatio = 16.0 / 9.0,
        .imageWidth = 400,
        .maxDepth = 50,
    };

    return try camera.render(alloc, progress, &world);
}
