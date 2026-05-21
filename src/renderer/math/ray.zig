const std = @import("std");
const vec3 = @import("../math/vec3.zig");

pub const Ray = struct {
    const Self = @This();

    origin: vec3.Point3,
    direction: vec3.Vec3,

    pub fn new(origin: vec3.Point3, direction: vec3.Vec3) Self {
        return Self{
            .origin = origin,
            .direction = direction,
        };
    }

    pub fn at(self: Self, t: f32) vec3.Point3 {
        return vec3.Point3.from(self.origin.toVec().add(self.direction.scale(t)));
    }
};

test "Creating ray is possible" {
    _ = Ray{
        .origin = vec3.Point3.new(0.0, 0.0, 0.0),
        .direction = vec3.Vec3.new(1.0, 0.0, 0.0),
    };
}

test "Ray at function returns correct point" {
    const ray = Ray{
        .origin = vec3.Point3.new(1.0, 2.0, 3.0),
        .direction = vec3.Vec3.new(0.0, 1.0, 0.0),
    };

    const point_at_t0 = ray.at(0.0);
    const point_at_t2 = ray.at(2.0);

    // At t=0, should return the origin
    const expected_t0 = vec3.Point3.new(1.0, 2.0, 3.0);
    try std.testing.expect(point_at_t0.equal(expected_t0));

    // At t=2, should return origin + direction * 2
    const expected_t2 = vec3.Point3.new(1.0, 4.0, 3.0);
    try std.testing.expect(point_at_t2.equal(expected_t2));
}

test "Ray at function with component access" {
    const ray = Ray{
        .origin = vec3.Point3.new(2.0, 1.0, 0.0),
        .direction = vec3.Vec3.new(1.0, 0.0, 1.0),
    };

    const point_at_t3 = ray.at(3.0);

    // Test individual components using our ergonomic getters
    try std.testing.expectEqual(@as(f32, 5.0), point_at_t3.getX()); // 2.0 + 1.0*3 = 5.0
    try std.testing.expectEqual(@as(f32, 1.0), point_at_t3.getY()); // 1.0 + 0.0*3 = 1.0
    try std.testing.expectEqual(@as(f32, 3.0), point_at_t3.getZ()); // 0.0 + 1.0*3 = 3.0
}
