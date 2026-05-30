const std = @import("std");
const ast = @import("../ast/root.zig");
const renderer = @import("../renderer/root.zig");
const reflect = @import("reflect.zig");

const Block = ast.block.Block;
const Camera = renderer.Camera;
const Material = renderer.Material;
const Sphere = renderer.hittables.Sphere;
const Hittable = renderer.hittables.Hittable;
const HittableList = renderer.hittables.HittableList;

pub const InterpretError = reflect.InterpretError;

pub const Scene = struct {
    camera: Camera,
    world: HittableList,
};

// -- Block type registry --

const Output = enum { material, hittable, camera };

const block_handlers = .{
    handler("LambertianMaterial", renderer.materials.Lambertian, .material),
    handler("MetalMaterial", renderer.materials.Metal, .material),
    handler("DielectricMaterial", renderer.materials.Dielectric, .material),
    handler("Camera", Camera, .camera),
    handler("Sphere", Sphere, .hittable),
};

fn handler(comptime name: []const u8, comptime T: type, comptime output: Output) type {
    const phase: enum { materials, objects } = if (output == .material) .materials else .objects;

    return struct {
        pub const block_name = name;
        pub const handler_phase = phase;

        pub fn apply(ctx: *Context, label: []const u8, block: Block) InterpretError!void {
            const parsed = try reflect.parseBlock(T, block, ctx);
            switch (output) {
                .material => try ctx.registerMaterial(label, Material.from(parsed)),
                .hittable => try ctx.addHittable(Hittable.from(parsed)),
                .camera => ctx.camera = parsed,
            }
        }
    };
}

// -- Context --

const Context = struct {
    alloc: std.mem.Allocator,
    camera: ?Camera,
    world: HittableList,
    materials: std.StringHashMap(*const Material),

    fn init(alloc: std.mem.Allocator) Context {
        return .{
            .alloc = alloc,
            .camera = null,
            .world = HittableList.new(alloc),
            .materials = std.StringHashMap(*const Material).init(alloc),
        };
    }

    fn registerMaterial(self: *Context, label: []const u8, mat: Material) InterpretError!void {
        const ptr = self.alloc.create(Material) catch return error.OutOfMemory;
        ptr.* = mat;
        self.materials.put(label, ptr) catch return error.OutOfMemory;
    }

    fn addHittable(self: *Context, h: Hittable) InterpretError!void {
        self.world.items.append(self.alloc, h) catch return error.OutOfMemory;
    }

    pub fn resolve(self: *Context, comptime T: type, label: []const u8) InterpretError!*const T {
        if (T == Material) {
            return self.materials.get(label) orelse error.UnresolvedRef;
        }
        @compileError("Unknown ref type: " ++ @typeName(T));
    }
};

// -- Interpret --

pub fn interpret(alloc: std.mem.Allocator, file: ast.file.File) InterpretError!Scene {
    var ctx = Context.init(alloc);

    try runPhase(&ctx, file, .materials);
    try runPhase(&ctx, file, .objects);

    return .{
        .camera = ctx.camera orelse return error.MissingCamera,
        .world = ctx.world,
    };
}

fn runPhase(ctx: *Context, file: ast.file.File, comptime phase: @TypeOf(.enum_literal)) InterpretError!void {
    for (file.items) |item| {
        switch (item) {
            .block => |block| {
                inline for (block_handlers) |Handler| {
                    if (Handler.handler_phase == phase and std.mem.eql(u8, block.type_name.value, Handler.block_name)) {
                        try Handler.apply(ctx, block.label.value, block);
                    }
                }
            },
            .attribute => {},
        }
    }
}
