const std = @import("std");
const renderer = @import("../renderer/root.zig");

pub const WebProgress = struct {
    total: std.atomic.Value(u64),
    current: std.atomic.Value(u64),

    pub fn init(alloc: std.mem.Allocator) !*WebProgress {
        const self = try alloc.create(WebProgress);
        self.total = .init(0);
        self.current = .init(0);
        return self;
    }

    pub fn progress(self: *WebProgress) renderer.Progress(WebProgress) {
        return .{ .context = self };
    }

    pub fn increment(self: *WebProgress, amount: u64) bool {
        _ = self.current.fetchAdd(amount, .monotonic);
        return false;
    }

    pub fn setTotal(self: *WebProgress, total: u64) void {
        self.total.store(total, .monotonic);
    }

    pub fn getTotal(self: *WebProgress) u64 {
        return self.total.load(.monotonic);
    }

    pub fn getCurrent(self: *WebProgress) u64 {
        return self.current.load(.monotonic);
    }

    pub fn getPercent(self: *WebProgress) u64 {
        const total = self.getTotal();
        if (total == 0) return 0;
        return @divFloor(self.getCurrent() * 100, total);
    }
};
