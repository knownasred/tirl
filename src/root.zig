//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
comptime {
    _ = @import("combinators/root.zig");
    _ = @import("ast/root.zig");
}
