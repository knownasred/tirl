const eitherImport = @import("either.zig");
const litteralImport = @import("litteral.zig");

pub const either = eitherImport.either;
pub const litteral = litteralImport.litteral;
pub const takeWhile = @import("multi.zig").takeWhile;
pub const lexme = @import("lexeme.zig").lexeme;
pub const seq = @import("seq.zig").seq;
pub const recognize = @import("recognize.zig").recognize;
pub const satisfy = @import("satisfy.zig").satisfy;
pub const delimited = @import("delimited.zig").delimited;
pub const many0 = @import("many.zig").many0;
pub const many1 = @import("many.zig").many1;
pub const opt = @import("opt.zig").opt;

// For tests
comptime {
    _ = @import("multi.zig");
    _ = @import("litteral.zig");
    _ = @import("either.zig");
    _ = @import("lexeme.zig");
    _ = @import("seq.zig");
    _ = @import("recognize.zig");
    _ = @import("satisfy.zig");
    _ = @import("delimited.zig");
    _ = @import("many.zig");
    _ = @import("opt.zig");
}
