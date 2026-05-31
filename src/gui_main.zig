const std = @import("std");
const rl = @import("raylib");
const zig_scene = @import("zig_scene");
const Image = zig_scene.renderer.Image;
const Color3 = zig_scene.renderer.math.Color3;
const Camera = zig_scene.renderer.Camera;
const HittableList = zig_scene.renderer.hittables.HittableList;

const UiProgress = zig_scene.ui.UiProgress;
const TileStatus = zig_scene.ui.TileStatus;

const INITIAL_SCALE = 2;
const PROGRESS_BAR_HEIGHT = 24;
const CORNER_LEN = 8;

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.skip();
    const path = args.next() orelse {
        std.debug.print("Usage: zig_scene_gui <scene-file>\n", .{});
        return;
    };

    const cwd = std.Io.Dir.cwd();
    const f = try cwd.openFile(init.io, path, .{});
    defer f.close(init.io);

    var read_buf: [4096]u8 = undefined;
    var reader = f.reader(init.io, &read_buf);
    const content = try reader.interface.allocRemaining(alloc, .unlimited);

    const parsed = zig_scene.ast.file.parse(alloc, content);
    const file = switch (parsed) {
        .ok => |tree| tree,
        .err => |err| {
            var err_buf: [256]u8 = undefined;
            const stderr = std.Io.File.stderr();
            var err_out = stderr.writer(init.io, &err_buf);
            try err.display(&err_out.interface);
            try err_out.flush();
            return;
        },
    };

    var scene = zig_scene.interpreter.interpret(alloc, file) catch |err| {
        std.debug.print("Interpret error: {}\n", .{err});
        return;
    };

    const render_width = scene.camera.imageWidth;
    const render_height: usize = @max(
        @as(usize, @intFromFloat(@as(f32, @floatFromInt(render_width)) / scene.camera.aspectRatio)),
        1,
    );
    const initial_window_width: i32 = @intCast(render_width * INITIAL_SCALE);
    const initial_window_height: i32 = @intCast(render_height * INITIAL_SCALE + PROGRESS_BAR_HEIGHT);

    const ui_progress = try zig_scene.ui.UiProgress.init(alloc, render_width, render_height);

    scene.camera.renderMode = .progressive;
    var render_future = try init.io.concurrent(renderWorker, .{ alloc, ui_progress, &scene.camera, &scene.world });

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(initial_window_width, initial_window_height, "Zig Raytracer");
    defer rl.closeWindow();
    rl.setTargetFPS(30);

    const pixels = try alloc.alloc(rl.Color, render_width * render_height);
    @memset(pixels, .{ .r = 0, .g = 0, .b = 0, .a = 255 });

    const image: rl.Image = .{
        .data = pixels.ptr,
        .width = @intCast(render_width),
        .height = @intCast(render_height),
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

        const win_w = rl.getScreenWidth();
        const win_h = rl.getScreenHeight();
        const scale = @as(f32, @floatFromInt(win_w)) / @as(f32, @floatFromInt(render_width));

        rl.beginDrawing();
        rl.clearBackground(.{ .r = 30, .g = 30, .b = 30, .a = 255 });
        rl.drawTextureEx(texture, .{ .x = 0, .y = @as(f32, PROGRESS_BAR_HEIGHT) }, 0, scale, rl.Color.white);

        drawTileCorners(ui_progress, scale);

        rl.drawRectangle(0, 0, win_w, PROGRESS_BAR_HEIGHT, .{ .r = 50, .g = 50, .b = 50, .a = 255 });

        if (total > 0) {
            const bar_width: i32 = @intFromFloat(@as(f32, @floatFromInt(win_w)) * @as(f32, @floatFromInt(@min(current, total))) / @as(f32, @floatFromInt(total)));
            rl.drawRectangle(0, 0, bar_width, PROGRESS_BAR_HEIGHT, .{ .r = 80, .g = 180, .b = 80, .a = 255 });
        }

        var buf: [64:0]u8 = undefined;
        const label = std.fmt.bufPrintZ(&buf, "{} / {} ({}x{})", .{ current, total, win_w, win_h }) catch "?";
        rl.drawText(label, 6, 4, 16, rl.Color.white);

        rl.endDrawing();
    }

    ui_progress.cancel();
    render_future.cancel(init.io);
}

fn drawTileCorners(ui_progress: *UiProgress, scale: f32) void {
    const tileStatus = ui_progress.tile_status orelse return;
    const tileSize: f32 = @floatFromInt(Camera.TILE_SIZE);
    const color: rl.Color = .{ .r = 255, .g = 100, .b = 50, .a = 220 };

    for (0..ui_progress.tiles_y) |ty| {
        for (0..ui_progress.tiles_x) |tx| {
            const idx = ty * ui_progress.tiles_x + tx;
            if (tileStatus[idx].load(.monotonic) != .rendering) continue;

            const fx1 = @as(f32, @floatFromInt(tx)) * tileSize * scale;
            const fy1 = @as(f32, @floatFromInt(ty)) * tileSize * scale + PROGRESS_BAR_HEIGHT;
            const fx2 = @min(@as(f32, @floatFromInt(tx + 1)) * tileSize, @as(f32, @floatFromInt(ui_progress.width))) * scale;
            const fy2 = @min(@as(f32, @floatFromInt(ty + 1)) * tileSize, @as(f32, @floatFromInt(ui_progress.height))) * scale + PROGRESS_BAR_HEIGHT;

            const thick: f32 = 3;
            const cl: f32 = CORNER_LEN;

            rl.drawLineEx(.{ .x = fx1, .y = fy1 }, .{ .x = fx1 + cl, .y = fy1 }, thick, color);
            rl.drawLineEx(.{ .x = fx1, .y = fy1 }, .{ .x = fx1, .y = fy1 + cl }, thick, color);
            rl.drawLineEx(.{ .x = fx2, .y = fy1 }, .{ .x = fx2 - cl, .y = fy1 }, thick, color);
            rl.drawLineEx(.{ .x = fx2, .y = fy1 }, .{ .x = fx2, .y = fy1 + cl }, thick, color);
            rl.drawLineEx(.{ .x = fx1, .y = fy2 }, .{ .x = fx1 + cl, .y = fy2 }, thick, color);
            rl.drawLineEx(.{ .x = fx1, .y = fy2 }, .{ .x = fx1, .y = fy2 - cl }, thick, color);
            rl.drawLineEx(.{ .x = fx2, .y = fy2 }, .{ .x = fx2 - cl, .y = fy2 }, thick, color);
            rl.drawLineEx(.{ .x = fx2, .y = fy2 }, .{ .x = fx2, .y = fy2 - cl }, thick, color);
        }
    }
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

fn renderWorker(alloc: std.mem.Allocator, ui_progress: *zig_scene.ui.UiProgress, camera: *const Camera, world: *const HittableList) void {
    _ = camera.render(alloc, ui_progress.progress(), world) catch |err| {
        std.debug.print("Render error: {}\n", .{err});
    };
}
