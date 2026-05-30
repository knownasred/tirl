const std = @import("std");
const zig_scene = @import("../root.zig");
const WebProgress = @import("progress.zig").WebProgress;
const Image = zig_scene.renderer.Image;

pub const Job = struct {
    id: u64,
    status: Status,
    web_progress: *WebProgress,
    image: ?Image,
    scene_source: []const u8,
    alloc: std.mem.Allocator,

    pub const Status = enum { pending, rendering, done, failed };

    fn renderInBackground(job: *Job, _: std.Io) void {
        job.status = .rendering;

        const parsed = zig_scene.ast.file.parse(job.alloc, job.scene_source);
        const file = switch (parsed) {
            .ok => |tree| tree,
            .err => {
                job.status = .failed;
                return;
            },
        };

        const scene = zig_scene.interpreter.interpret(job.alloc, file) catch {
            job.status = .failed;
            return;
        };

        var camera = scene.camera;
        camera.renderMode = .perPixel;
        const image = camera.render(job.alloc, job.web_progress.progress(), &scene.world) catch {
            job.status = .failed;
            return;
        };

        job.image = image;
        job.status = .done;
    }
};

pub const JobStore = struct {
    jobs: std.AutoHashMap(u64, *Job),
    next_id: std.atomic.Value(u64),
    mutex: std.Io.Mutex,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) JobStore {
        return .{
            .jobs = std.AutoHashMap(u64, *Job).init(alloc),
            .next_id = .init(1),
            .mutex = .init,
            .alloc = alloc,
        };
    }

    pub fn createJob(self: *JobStore, scene_source: []const u8, io: std.Io) !u64 {
        const id = self.next_id.fetchAdd(1, .monotonic);

        const wp = try WebProgress.init(self.alloc);
        const job = try self.alloc.create(Job);
        job.* = .{
            .id = id,
            .status = .pending,
            .web_progress = wp,
            .image = null,
            .scene_source = scene_source,
            .alloc = self.alloc,
        };

        {
            try self.mutex.lock(io);
            defer self.mutex.unlock(io);
            try self.jobs.put(id, job);
        }

        _ = try io.concurrent(Job.renderInBackground, .{ job, io });

        return id;
    }

    pub fn getJob(self: *JobStore, id: u64, io: std.Io) !?*Job {
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        return self.jobs.get(id);
    }
};

pub fn run(alloc: std.mem.Allocator, port: u16, io: std.Io) !void {
    var addr: std.Io.net.IpAddress = .{ .ip4 = .loopback(port) };
    var server = try std.Io.net.IpAddress.listen(&addr, io, .{ .reuse_address = true });
    defer server.deinit(io);

    std.debug.print("Server listening on http://127.0.0.1:{d}\n", .{port});

    var store = JobStore.init(alloc);

    while (true) {
        var stream = try server.accept(io);

        var read_buf: [8192]u8 = undefined;
        var write_buf: [8192]u8 = undefined;
        var reader = std.Io.net.Stream.Reader.init(stream, io, &read_buf);
        var writer = std.Io.net.Stream.Writer.init(stream, io, &write_buf);

        var http_server = std.http.Server.init(&reader.interface, &writer.interface);

        handleConnection(alloc, &http_server, &store, io) catch |err| {
            std.debug.print("Connection error: {}\n", .{err});
        };

        stream.close(io);
    }
}

fn handleConnection(alloc: std.mem.Allocator, server: *std.http.Server, store: *JobStore, io: std.Io) !void {
    var request = try server.receiveHead();
    const target = request.head.target;

    if (request.head.method == .POST and std.mem.eql(u8, target, "/submit")) {
        try handleSubmit(alloc, &request, store, io);
    } else if (request.head.method == .GET) {
        if (parseJobRoute(target)) |route| {
            switch (route.action) {
                .status => try handleStatus(&request, store, route.id, io),
                .output => try handleOutput(alloc, &request, store, route.id, io),
            }
        } else {
            try request.respond("Not found\n", .{ .status = .not_found });
        }
    } else {
        try request.respond("Not found\n", .{ .status = .not_found });
    }
}

const Route = struct {
    id: u64,
    action: enum { status, output },
};

fn parseJobRoute(target: []const u8) ?Route {
    if (target.len < 2 or target[0] != '/') return null;
    const rest = target[1..];

    const slash_pos = std.mem.indexOfScalar(u8, rest, '/') orelse return null;
    const id_str = rest[0..slash_pos];
    const action_str = rest[slash_pos + 1 ..];

    const id = std.fmt.parseInt(u64, id_str, 10) catch return null;

    if (std.mem.eql(u8, action_str, "status")) return .{ .id = id, .action = .status };
    if (std.mem.eql(u8, action_str, "output")) return .{ .id = id, .action = .output };
    return null;
}

fn handleSubmit(alloc: std.mem.Allocator, request: *std.http.Server.Request, store: *JobStore, io: std.Io) !void {
    var body_buf: [65536]u8 = undefined;
    var body_reader = request.readerExpectNone(&body_buf);
    const body = try body_reader.allocRemaining(alloc, .unlimited);

    const id = try store.createJob(body, io);

    var response_buf: [64]u8 = undefined;
    const response = std.fmt.bufPrint(&response_buf, "{{\"id\": {d}}}\n", .{id}) catch unreachable;

    try request.respond(response, .{
        .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
    });
}

fn handleStatus(request: *std.http.Server.Request, store: *JobStore, id: u64, io: std.Io) !void {
    const job = (try store.getJob(id, io)) orelse {
        try request.respond("{\"error\": \"not found\"}\n", .{ .status = .not_found });
        return;
    };

    var buf: [128]u8 = undefined;
    const status_str = @tagName(job.status);
    const percent = job.web_progress.getPercent();
    const response = std.fmt.bufPrint(&buf, "{{\"status\": \"{s}\", \"progress\": {d}}}\n", .{ status_str, percent }) catch unreachable;

    try request.respond(response, .{
        .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
    });
}

fn handleOutput(alloc: std.mem.Allocator, request: *std.http.Server.Request, store: *JobStore, id: u64, io: std.Io) !void {
    const job = (try store.getJob(id, io)) orelse {
        try request.respond("{\"error\": \"not found\"}\n", .{ .status = .not_found });
        return;
    };

    if (job.status != .done) {
        try request.respond("{\"error\": \"not ready\"}\n", .{ .status = .conflict });
        return;
    }

    const image = job.image orelse {
        try request.respond("{\"error\": \"no image\"}\n", .{ .status = .internal_server_error });
        return;
    };

    var out: std.Io.Writer.Allocating = .init(alloc);
    defer out.deinit();
    try image.write(&out.writer);

    try request.respond(out.written(), .{
        .extra_headers = &.{.{ .name = "content-type", .value = "image/x-portable-pixmap" }},
    });
}
