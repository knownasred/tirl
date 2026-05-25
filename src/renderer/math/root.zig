pub const Interval = @import("interval.zig");
pub const Ray = @import("ray.zig").Ray;
const vec3 = @import("vec3.zig");
pub const Vec3 = vec3.Vec3;
pub const Point3 = vec3.Point3;
pub const Color3 = vec3.Color3;

pub inline fn toFloat(val: anytype) f32 {
    return @as(f32, @floatFromInt(val));
}

pub inline fn toInt(val: anytype) usize {
    return @as(usize, @intFromFloat(val));
}
