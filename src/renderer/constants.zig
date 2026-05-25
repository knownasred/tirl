const std = @import("std");

pub const infinity = std.math.inf(f32);
pub const pi = @as(f32, std.math.pi);

pub inline fn deg_to_rad(degrees: f32) f32 {
    return degrees * pi / 180;
}

var prng: ?std.Random.DefaultPrng = null;
const SEED = 1334;

pub fn random() std.Random {
    if (prng == null) prng = .init(SEED);
    return prng.?.random();
}

pub inline fn randomDouble() f32 {
    return random().float(f32);
}
pub inline fn randomDoubleRanged(min: f32, max: f32) f32 {
    return min + (max - min) * randomDouble();
}
