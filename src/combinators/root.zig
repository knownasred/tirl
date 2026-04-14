const eitherImport = @import("either.zig");
const litteralImport = @import("litteral.zig");

pub const either = eitherImport.either;
pub const litteral = litteralImport.litteral;
pub const multi = @import("multi.zig");

// For tests
comptime {
    _ = @import("multi.zig");
    _ = @import("litteral.zig");
    _ = @import("either.zig");
}
