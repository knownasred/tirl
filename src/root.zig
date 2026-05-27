//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub const renderer = @import("renderer/root.zig");
pub const tui = @import("tui/root.zig");
pub const web = @import("web/root.zig");
pub const ui = @import("ui/root.zig");

comptime {
    _ = @import("combinators/root.zig");
    _ = @import("ast/root.zig");
    _ = @import("renderer/img/root.zig");
    _ = @import("web/root.zig");
    _ = @import("ui/root.zig");
}
