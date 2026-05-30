const Color3 = @import("math/root.zig").Color3;

pub fn Progress(comptime T: type) type {
    return struct {
        context: *T,

        const Self = @This();

        pub fn increment(self: Self, amount: u64) bool {
            return self.context.increment(amount);
        }

        pub fn setTotal(self: Self, total: u64) void {
            self.context.setTotal(total);
        }

        pub fn onPixel(self: Self, row: usize, col: usize, sample: usize, color: Color3) void {
            if (comptime @hasDecl(T, "onPixel")) {
                self.context.onPixel(row, col, sample, color);
            }
        }

        pub fn onTileStart(self: Self, tileIdx: usize) void {
            if (comptime @hasDecl(T, "onTileStart")) {
                self.context.onTileStart(tileIdx);
            }
        }

        pub fn onTileEnd(self: Self, tileIdx: usize) void {
            if (comptime @hasDecl(T, "onTileEnd")) {
                self.context.onTileEnd(tileIdx);
            }
        }
    };
}
