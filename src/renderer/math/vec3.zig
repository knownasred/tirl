const std = @import("std");
const constants = @import("../constants.zig");
pub const Vec3 = struct {
    pos: @Vector(3, f32),

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .pos = .{ x, y, z } };
    }

    pub fn getX(self: Vec3) f32 {
        return self.pos[0];
    }

    pub fn getY(self: Vec3) f32 {
        return self.pos[1];
    }

    pub fn getZ(self: Vec3) f32 {
        return self.pos[2];
    }

    pub fn zero() Vec3 {
        return Vec3{ .pos = .{ 0.0, 0.0, 0.0 } };
    }

    pub fn one() Vec3 {
        return Vec3{ .pos = .{ 1.0, 1.0, 1.0 } };
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return Vec3{ .pos = self.pos + other.pos };
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return Vec3{ .pos = self.pos - other.pos };
    }

    pub fn mul(self: Vec3, other: Vec3) Vec3 {
        return Vec3{ .pos = self.pos * other.pos };
    }

    pub fn div(self: Vec3, other: Vec3) Vec3 {
        return Vec3{ .pos = self.pos / other.pos };
    }

    pub fn mul_s(self: Vec3, scalar: f32) Vec3 {
        return Vec3{ .pos = self.pos * @as(@Vector(3, f32), @splat(scalar)) };
    }

    pub fn div_s(self: Vec3, scalar: f32) Vec3 {
        return Vec3{ .pos = self.pos / @as(@Vector(3, f32), @splat(scalar)) };
    }

    pub fn negate(self: Vec3) Vec3 {
        return Vec3{ .pos = -self.pos };
    }

    pub fn dot(self: Vec3, other: Vec3) f32 {
        return @reduce(.Add, self.pos * other.pos);
    }

    pub fn length(self: Vec3) f32 {
        return @sqrt(self.length_squared());
    }

    pub fn length_squared(self: Vec3) f32 {
        const squared = self.pos * self.pos;
        return @reduce(.Add, squared);
    }

    pub fn equal(self: Vec3, other: Vec3) bool {
        // Use SIMD comparison to check all components at once
        const cmp = self.pos == other.pos;
        return @reduce(.And, cmp);
    }

    pub fn unit(self: Vec3) Vec3 {
        return self.div_s(self.length());
    }

    pub fn random() Vec3 {
        return .new(
            constants.randomDouble(),
            constants.randomDouble(),
            constants.randomDouble(),
        );
    }

    pub fn randomRanged(min: f32, max: f32) Vec3 {
        return .new(
            constants.randomDoubleRanged(min, max),
            constants.randomDoubleRanged(min, max),
            constants.randomDoubleRanged(min, max),
        );
    }

    pub inline fn randomUnit() Vec3 {
        while (true) {
            const p = Vec3.randomRanged(-1, 1);
            const lengthSquared = p.length_squared();

            if (1e-160 <= lengthSquared and lengthSquared <= 1) {
                return p.div_s(@sqrt(lengthSquared));
            }
        }
    }

    pub inline fn randomOnHemisphere(normal: Vec3) Vec3 {
        const onUnitSphere = Vec3.randomUnit();
        if (onUnitSphere.dot(normal) > 0.0) { // In the same hemisphere as the normal
            return onUnitSphere;
        } else {
            return onUnitSphere.negate();
        }
    }
};

fn PhantomWrapper(comptime T: type, comptime nameInner: []const u8) type {
    // Used to ensure that the types are actually different
    return struct {
        const Self = @This();
        inner: T,

        pub inline fn new(x: f32, y: f32, z: f32) Self {
            // Use @call to dynamically invoke the inner type's init function
            const inner_value = @call(.auto, T.new, .{ x, y, z });
            return Self{ .inner = inner_value };
        }

        pub inline fn getX(self: Self) f32 {
            return self.inner.getX();
        }

        pub inline fn getY(self: Self) f32 {
            return self.inner.getY();
        }

        pub inline fn getZ(self: Self) f32 {
            return self.inner.getZ();
        }

        pub inline fn from(value: T) Self {
            return Self{ .inner = value };
        }

        pub inline fn toVec(self: Self) T {
            return self.inner;
        }

        pub inline fn name(_: Self) []const u8 {
            return nameInner;
        }

        pub inline fn equal(self: Self, other: Self) bool {
            return self.inner.equal(other.inner);
        }
    };
}

pub const Point3 = PhantomWrapper(Vec3, "Point3");

pub const Color3 = PhantomWrapper(Vec3, "Color3");

test "Initialize Vec3" {
    const vec = Vec3.new(1.0, 2.0, 3.0);
    const expected = Vec3.new(1.0, 2.0, 3.0);
    try std.testing.expect(vec.equal(expected));
}

test "Vec3 zero" {
    const vec = Vec3.zero();
    const expected = Vec3.new(0.0, 0.0, 0.0);
    try std.testing.expect(vec.equal(expected));
}

test "Vec3 one" {
    const vec = Vec3.one();
    const expected = Vec3.new(1.0, 1.0, 1.0);
    try std.testing.expect(vec.equal(expected));
}

test "Vec3 add" {
    const v1 = Vec3.new(1.0, 2.0, 3.0);
    const v2 = Vec3.new(4.0, 5.0, 6.0);
    const result = v1.add(v2);
    const expected = Vec3.new(5.0, 7.0, 9.0);
    try std.testing.expect(result.equal(expected));
}

test "Vec3 sub" {
    const v1 = Vec3.new(5.0, 7.0, 9.0);
    const v2 = Vec3.new(1.0, 2.0, 3.0);
    const result = v1.sub(v2);
    const expected = Vec3.new(4.0, 5.0, 6.0);
    try std.testing.expect(result.equal(expected));
}

test "Vec3 mul" {
    const v1 = Vec3.new(2.0, 3.0, 4.0);
    const v2 = Vec3.new(5.0, 6.0, 7.0);
    const result = v1.mul(v2);
    const expected = Vec3.new(10.0, 18.0, 28.0);
    try std.testing.expect(result.equal(expected));
}

test "Vec3 div" {
    const v1 = Vec3.new(10.0, 15.0, 20.0);
    const v2 = Vec3.new(2.0, 3.0, 4.0);
    const result = v1.div(v2);
    const expected = Vec3.new(5.0, 5.0, 5.0);
    try std.testing.expect(result.equal(expected));
}

test "Vec3 scale" {
    const vec = Vec3.new(2.0, 3.0, 4.0);
    const result = vec.mul_s(2.5);
    const expected = Vec3.new(5.0, 7.5, 10.0);
    try std.testing.expect(result.equal(expected));
}

test "Vec3 negate" {
    const vec = Vec3.new(1.0, -2.0, 3.0);
    const result = vec.negate();
    const expected = Vec3.new(-1.0, 2.0, -3.0);
    try std.testing.expect(result.equal(expected));
}

test "Vec3 length_squared" {
    const vec = Vec3.new(3.0, 4.0, 0.0);
    const result = vec.length_squared();
    try std.testing.expectEqual(@as(f32, 25.0), result);
}

test "Vec3 length" {
    const vec = Vec3.new(3.0, 4.0, 0.0);
    const result = vec.length();
    try std.testing.expectEqual(@as(f32, 5.0), result);
}

test "Vec3 length with 3D vector" {
    const vec = Vec3.new(2.0, 3.0, 6.0);
    const result = vec.length();
    try std.testing.expectEqual(@as(f32, 7.0), result);
}

test "Vec3 equal" {
    // Test equal vectors
    const v1 = Vec3.new(1.0, 2.0, 3.0);
    const v2 = Vec3.new(1.0, 2.0, 3.0);
    try std.testing.expect(v1.equal(v2));

    // Test unequal vectors - different x
    const v3 = Vec3.new(1.5, 2.0, 3.0);
    try std.testing.expect(!v1.equal(v3));

    // Test unequal vectors - different y
    const v4 = Vec3.new(1.0, 2.5, 3.0);
    try std.testing.expect(!v1.equal(v4));

    // Test unequal vectors - different z
    const v5 = Vec3.new(1.0, 2.0, 3.5);
    try std.testing.expect(!v1.equal(v5));

    // Test with zero vectors
    const zero1 = Vec3.zero();
    const zero2 = Vec3.zero();
    try std.testing.expect(zero1.equal(zero2));

    // Test with negative values
    const neg1 = Vec3.new(-1.0, -2.0, -3.0);
    const neg2 = Vec3.new(-1.0, -2.0, -3.0);
    try std.testing.expect(neg1.equal(neg2));
}

test "Vec3 edge cases" {
    // Test with negative values
    const neg = Vec3.new(-1.0, -2.0, -3.0);
    const expected_neg = Vec3.new(-1.0, -2.0, -3.0);
    try std.testing.expect(neg.equal(expected_neg));

    // Test zero vector length
    const zero = Vec3.zero();
    try std.testing.expectEqual(@as(f32, 0.0), zero.length());
    try std.testing.expectEqual(@as(f32, 0.0), zero.length_squared());

    // Test scale with zero
    const scaled_zero = Vec3.new(5.0, 10.0, 15.0).mul_s(0.0);
    const expected_zero = Vec3.zero();
    try std.testing.expect(scaled_zero.equal(expected_zero));
}
