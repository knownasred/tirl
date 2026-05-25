const constants = @import("../constants.zig");

min: f32 = -constants.infinity,
max: f32 = constants.infinity,

pub fn size(self: @This()) f32 {
    return self.max - self.min;
}

pub fn contains(self: @This(), value: f32) bool {
    return self.min <= value and value <= self.max;
}

pub fn surrounds(self: @This(), value: f32) bool {
    return self.min < value and value < self.max;
}

pub const empty = @This(){
    .min = constants.infinity,
    .max = -constants.infinity,
};

pub const universe = @This(){
    .min = -constants.infinity,
    .max = constants.infinity,
};

pub fn clamp(self: @This(), x: f32) f32 {
    if (x < self.min) {
        return self.min;
    }
    if (x > self.max) {
        return self.max;
    }

    return x;
}
