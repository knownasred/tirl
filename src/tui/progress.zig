const std = @import("std");
const builtin = @import("builtin");

const RESET_LINE = "\x1B[2K\r";
const HIDE_CURSOR = "\x1B[?25l";
const SHOW_CURSOR = "\x1B[?25h";

const spinner: [10][]const u8 = .{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" };

fn repeatString(allocator: std.mem.Allocator, str: []const u8, count: usize) ![]u8 {
    if (count == 0) return allocator.dupe(u8, "");

    const total_len = str.len * count;
    const result = try allocator.alloc(u8, total_len);

    var i: usize = 0;
    while (i < count) : (i += 1) {
        @memcpy(result[i * str.len .. (i + 1) * str.len], str);
    }

    return result;
}

fn getTerminalWidth() anyerror!u16 {
    const stdout = std.Io.File.stdout();
    return switch (builtin.os.tag) {
        .windows => blk: {
            var buf: std.os.windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
            break :blk switch (std.os.windows.kernel32.GetConsoleScreenBufferInfo(
                stdout.handle,
                &buf,
            )) {
                std.os.windows.TRUE => @intCast(buf.srWindow.Right - buf.srWindow.Left + 1),
                else => error.Unexpected,
            };
        },
        .linux, .macos => blk: {
            var buf: std.posix.winsize = undefined;
            break :blk switch (std.posix.errno(
                std.posix.system.ioctl(
                    stdout.handle,
                    std.posix.T.IOCGWINSZ,
                    @intFromPtr(&buf),
                ),
            )) {
                .SUCCESS => buf.col,
                else => error.IoctlError,
            };
        },
        else => error.Unsupported,
    };
}

fn loadingBar(alloc: std.mem.Allocator, current: u64, total: u64) ![]const u8 {
    std.debug.assert(current <= total);
    std.debug.assert(total != 0);

    const percentage = @divFloor(current * 100, total);
    // Get the width of the terminal
    const width = getTerminalWidth() catch 20;

    const barWidth = width - 20; // Subtract the width of the percentage and brackets
    const filledWidth = @divFloor(barWidth * percentage, 100);
    const emptyWidth = barWidth - filledWidth;

    const filledPart = try repeatString(alloc, "█", filledWidth);
    const emptyPart = try repeatString(alloc, " ", emptyWidth);

    return std.fmt.allocPrint(alloc, "[{s}{s}]", .{ filledPart, emptyPart });
}

pub const Progress = struct {
    total: std.atomic.Value(u64),
    future: ?std.Io.Future(void),
    current: std.atomic.Value(u64),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, total: u64) *Progress {
        const progress = alloc.create(Progress) catch unreachable;
        progress.total = .init(total);
        progress.current = .init(0);
        progress.future = null;
        progress.alloc = alloc;
        return progress;
    }

    fn run(self: *Progress, io: std.Io) void {
        std.debug.print(HIDE_CURSOR, .{});
        var index: usize = 0;
        mainLoop: while (true) {
            // Note: Due to how IO is setup (https://ziglang.org/download/0.16.0/release-notes.html#Cancelation),
            // please don't use anything related to IO here, unless you handle the cancelation (see below).
            // Otherwise you might have a bad surprise during rendering
            const total = self.total.load(.monotonic);
            const current = self.current.load(.monotonic);

            // Reset the progress bar to the start of the line
            std.debug.print(RESET_LINE, .{});

            const percentage = @divFloor(current * 100, total);
            std.debug.print("{s} {s} {d}% ({d}/{d})", .{
                spinner[index % spinner.len],
                loadingBar(self.alloc, current, total) catch @panic("failed to allocate!"),
                percentage,
                current,
                total,
            });

            index += 1;

            // rerender 10 times per second (and exit if cancelled)
            io.sleep(.fromMilliseconds(100), .awake) catch {
                // Cancel was requested, great!
                break :mainLoop;
            };
        }

        const total = self.total.load(.monotonic);
        const current = self.current.load(.monotonic);

        const percentage = @divFloor(current * 100, total);
        std.debug.print(RESET_LINE, .{});
        std.debug.print("✓ {s} {d}% ({d}/{d})", .{ loadingBar(self.alloc, current, total) catch @panic("failed to allocate!"), percentage, current, total });
    }

    pub fn start(self: *Progress, io: std.Io) anyerror!void {
        self.future = try io.concurrent(Progress.run, .{ self, io });
    }

    pub fn increment(self: *Progress, amount: u64) void {
        const val = self.current.fetchAdd(amount, .monotonic);
        std.debug.assert((val + amount) <= self.total.load(.monotonic));
    }

    pub fn finish(self: *Progress, io: std.Io) void {
        if (self.future) |*value| {
            value.cancel(io);
        }

        std.debug.print("{s}\n", .{SHOW_CURSOR});
    }

    pub fn setTotal(self: *Progress, total: u64) void {
        std.debug.assert(total != 0);
        self.total.store(total, .monotonic);
    }
};
