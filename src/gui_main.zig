const std = @import("std");
const rl = @import("raylib");
const zig_scene = @import("zig_scene");
const Image = zig_scene.renderer.Image;
const Color3 = zig_scene.renderer.math.Color3;

const RENDER_WIDTH = 400;
const RENDER_HEIGHT = @as(usize, @max(
    @as(usize, @intFromFloat(@as(f32, @floatFromInt(RENDER_WIDTH)) / (16.0 / 9.0))),
    1,
));
const SCALE = 2;
const PROGRESS_BAR_HEIGHT = 24;
const WINDOW_WIDTH = RENDER_WIDTH * SCALE;
const WINDOW_HEIGHT = RENDER_HEIGHT * SCALE + PROGRESS_BAR_HEIGHT;

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();

    const ui_progress = try zig_scene.ui.UiProgress.init(alloc, RENDER_WIDTH, RENDER_HEIGHT);

    var render_future = try init.io.concurrent(renderWorker, .{ alloc, ui_progress });

    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Zig Raytracer");
    defer rl.closeWindow();
    rl.setTargetFPS(30);

    const pixels = try alloc.alloc(rl.Color, RENDER_WIDTH * RENDER_HEIGHT);
    @memset(pixels, .{ .r = 0, .g = 0, .b = 0, .a = 255 });

    const image: rl.Image = .{
        .data = pixels.ptr,
        .width = RENDER_WIDTH,
        .height = RENDER_HEIGHT,
        .mipmaps = 1,
        .format = .uncompressed_r8g8b8a8,
    };

    const texture = try rl.loadTextureFromImage(image);
    defer rl.unloadTexture(texture);

    while (!rl.windowShouldClose()) {
        copyBufferToPixels(ui_progress.display_buffer, pixels);
        rl.updateTexture(texture, pixels.ptr);

        const current = ui_progress.current.load(.monotonic);
        const total = ui_progress.total.load(.monotonic);

        rl.beginDrawing();
        rl.clearBackground(.{ .r = 30, .g = 30, .b = 30, .a = 255 });
        rl.drawTextureEx(texture, .{ .x = 0, .y = @as(f32, PROGRESS_BAR_HEIGHT) }, 0, SCALE, rl.Color.white);

        // Progress bar background
        rl.drawRectangle(0, 0, WINDOW_WIDTH, PROGRESS_BAR_HEIGHT, .{ .r = 50, .g = 50, .b = 50, .a = 255 });

        if (total > 0) {
            const bar_width: i32 = @intFromFloat(@as(f32, @floatFromInt(WINDOW_WIDTH)) * @as(f32, @floatFromInt(@min(current, total))) / @as(f32, @floatFromInt(total)));
            rl.drawRectangle(0, 0, bar_width, PROGRESS_BAR_HEIGHT, .{ .r = 80, .g = 180, .b = 80, .a = 255 });
        }

        var buf: [64:0]u8 = undefined;
        const label = std.fmt.bufPrintZ(&buf, "{} / {}", .{ current, total }) catch "?";
        rl.drawText(label, 6, 4, 16, rl.Color.white);

        rl.endDrawing();
    }

    ui_progress.cancel();
    render_future.cancel(init.io);
}

fn copyBufferToPixels(display_buffer: []Color3, pixels: []rl.Color) void {
    for (display_buffer, pixels) |color, *pixel| {
        pixel.r = colorToU8(Image.linear_to_gamma(color.getX()));
        pixel.g = colorToU8(Image.linear_to_gamma(color.getY()));
        pixel.b = colorToU8(Image.linear_to_gamma(color.getZ()));
        pixel.a = 255;
    }
}

fn colorToU8(value: f32) u8 {
    return @intFromFloat(@min(@max(value * 256.0, 0.0), 255.0));
}

fn renderWorker(alloc: std.mem.Allocator, ui_progress: *zig_scene.ui.UiProgress) void {
    _ = zig_scene.renderer.render(alloc, ui_progress.progress(), .progressive) catch |err| {
        std.debug.print("Render error: {}\n", .{err});
    };
}
