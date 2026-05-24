const std = @import("std");

pub const infinity = std.math.inf(f32);
pub const pi = @as(f32, std.math.pi);

pub inline fn deg_to_rad(degrees: f32) f32 {
    return degrees * pi / 180;
}
