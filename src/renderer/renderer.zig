const renderer = @import("root.zig");
const Image = renderer.Image;
const Color3 = renderer.math.Color3;
const Point3 = renderer.math.Point3;
const Vec3 = renderer.math.Vec3;
const Ray = renderer.math.Ray;
const toFloat = renderer.math.toFloat;
const toInt = renderer.math.toInt;

const std = @import("std");

const hittables = @import("hittables/root.zig");
const materials = @import("materials/root.zig");
const Material = materials.Material;
const constants = @import("constants.zig");
const Camera = @import("camera.zig");

pub fn render(alloc: std.mem.Allocator, progress: anytype, renderMode: Camera.RenderMode) !Image {
    // World
    var world = hittables.HittableList.new(alloc);

    const materialGround = Material.from(materials.Lambertian{ .albedo = .new(0.8, 0.8, 0.0) });
    const materialCenter = Material.from(materials.Lambertian{ .albedo = .new(0.1, 0.2, 0.5) });
    const materialLeft = Material.from(materials.Dielectric{ .refractionIndex = 1.50 });
    const materialBubble = Material.from(materials.Dielectric{ .refractionIndex = 1.00 / 1.50 });
    const materialRight = Material.from(materials.Metal{ .albedo = .new(0.8, 0.6, 0.2), .fuzz = 1.0 });

    try world.add(.{ .sphere = .{ .position = .new(0, -100.5, -1), .radius = 100, .material = &materialGround } });
    try world.add(.{ .sphere = .{ .position = .new(0, 0, -1.2), .radius = 0.5, .material = &materialCenter } });
    try world.add(.{ .sphere = .{ .position = .new(-1, 0, -1), .radius = 0.5, .material = &materialLeft } });
    try world.add(.{ .sphere = .{ .position = .new(-1, 0, -1), .radius = 0.4, .material = &materialBubble } });
    try world.add(.{ .sphere = .{ .position = .new(1, 0, -1), .radius = 0.5, .material = &materialRight } });

    const camera: Camera = .{
        .aspectRatio = 16.0 / 9.0,
        .imageWidth = 400,
        .maxDepth = 50,
        .samplesPerPixel = 100,
        .vfov = 90,
        .lookFrom = .new(0, 0, 0),
        .lookAt = .new(0, 0, -1),
        .vup = .new(0, 1, 0),

        .defocusAngle = 4,
        .focusDistance = 1,
        .renderMode = renderMode,
    };

    return try camera.render(alloc, progress, &world);
}
