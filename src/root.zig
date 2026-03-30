//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const combinator = @import("combinators.zig");

comptime {
    _ = @import("combinators.zig");
    _ = @import("combinators/root.zig");
}
