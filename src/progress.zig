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
    const stdout = std.fs.File.stdout();
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
    mutex: std.Thread.Mutex,
    total: u64,
    cancel: bool,
    threadHandle: ?std.Thread,
    current: u64,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, total: u64) *Progress {
        const progress = alloc.create(Progress) catch unreachable;
        progress.total = total;
        progress.current = 0;
        progress.threadHandle = null;
        progress.alloc = alloc;
        return progress;
    }

    fn run(self: *Progress) void {
        std.debug.print(HIDE_CURSOR, .{});
        var index: usize = 0;
        var shouldStop = false;
        while (!shouldStop) {
            if (self.cancel) {
                shouldStop = true;
            }

            self.mutex.lock();
            const total = self.total;
            const current = self.current;
            self.mutex.unlock();

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

            // rerender 10 times per second
            std.Thread.sleep(std.time.ns_per_ms * 100);
        }

        self.mutex.lock();
        const total = self.total;
        const current = self.current;
        self.mutex.unlock();

        const percentage = @divFloor(current * 100, total);
        std.debug.print(RESET_LINE, .{});
        std.debug.print("✓ {s} {d}% ({d}/{d})", .{ loadingBar(self.alloc, current, total) catch @panic("failed to allocate!"), percentage, current, total });
    }

    pub fn start(self: *Progress) anyerror!void {
        // Start starts a thread that shows in the terminal the contents
        self.threadHandle = try std.Thread.spawn(.{}, Progress.run, .{self});
    }

    pub fn increment(self: *Progress, amount: u64) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.current += amount;
    }

    pub fn finish(self: *Progress) void {
        self.mutex.lock();
        self.cancel = true;
        self.mutex.unlock();

        self.threadHandle.?.join();

        std.debug.print("{s}\n", .{SHOW_CURSOR});
    }

    pub fn setTotal(self: *Progress, total: u64) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.total = total;
    }
};
