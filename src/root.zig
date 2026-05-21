//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub const renderer = @import("renderer/root.zig");
pub const tui = @import("tui/root.zig");

comptime {
    _ = @import("combinators/root.zig");
    _ = @import("ast/root.zig");
    _ = @import("renderer/img/root.zig");
}
