const std = @import("std");
const renderer = @import("../renderer/root.zig");
const Camera = renderer.Camera;
const Color3 = renderer.math.Color3;

pub const TileStatus = enum(u8) { idle = 0, rendering = 1, done = 2 };

pub const UiProgress = struct {
    display_buffer: []Color3,
    width: usize,
    height: usize,
    current: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    total: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    cancelled: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    tile_status: ?[]std.atomic.Value(TileStatus) = null,
    tiles_x: usize = 0,
    tiles_y: usize = 0,

    pub fn init(alloc: std.mem.Allocator, width: usize, height: usize) !*UiProgress {
        const self = try alloc.create(UiProgress);
        const buffer = try alloc.alloc(Color3, width * height);
        @memset(buffer, Color3.new(0, 0, 0));

        const tilesX = (width + Camera.TILE_SIZE - 1) / Camera.TILE_SIZE;
        const tilesY = (height + Camera.TILE_SIZE - 1) / Camera.TILE_SIZE;
        const tileCount = tilesX * tilesY;
        const tileStatus = try alloc.alloc(std.atomic.Value(TileStatus), tileCount);
        for (tileStatus) |*ts| ts.* = std.atomic.Value(TileStatus).init(.idle);

        self.* = .{
            .display_buffer = buffer,
            .width = width,
            .height = height,
            .tile_status = tileStatus,
            .tiles_x = tilesX,
            .tiles_y = tilesY,
        };
        return self;
    }

    pub fn progress(self: *UiProgress) renderer.Progress(UiProgress) {
        return .{ .context = self };
    }

    pub fn increment(self: *UiProgress, amount: u64) bool {
        _ = self.current.fetchAdd(amount, .monotonic);
        return self.cancelled.load(.monotonic);
    }

    pub fn cancel(self: *UiProgress) void {
        self.cancelled.store(true, .monotonic);
    }

    pub fn isCancelled(self: *UiProgress) bool {
        return self.cancelled.load(.monotonic);
    }

    pub fn setTotal(self: *UiProgress, total: u64) void {
        self.total.store(total, .monotonic);
    }

    pub fn onPixel(self: *UiProgress, row: usize, col: usize, sample: usize, color: Color3) void {
        _ = sample;
        self.display_buffer[row * self.width + col] = color;
    }

    pub fn onTileStart(self: *UiProgress, tileIdx: usize) void {
        if (self.tile_status) |ts| {
            ts[tileIdx].store(.rendering, .monotonic);
        }
    }

    pub fn onTileEnd(self: *UiProgress, tileIdx: usize) void {
        if (self.tile_status) |ts| {
            ts[tileIdx].store(.done, .monotonic);
        }
    }

    pub fn reset(self: *UiProgress) void {
        self.cancelled.store(false, .monotonic);
        self.current.store(0, .monotonic);
        self.total.store(0, .monotonic);
        @memset(self.display_buffer, Color3.new(0, 0, 0));
        if (self.tile_status) |ts| {
            for (ts) |*t| t.store(.idle, .monotonic);
        }
    }
};
