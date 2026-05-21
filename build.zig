const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("zig_scene", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const zigimg_dependency = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    mod.addImport("zigimg", zigimg_dependency.module("zigimg"));

    const exe = b.addExecutable(.{
        .name = "zig_scene",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zig_scene", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    const print_ast_exe = b.addExecutable(.{
        .name = "print_ast",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/print_ast.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zig_scene", .module = mod },
            },
        }),
    });

    const parse_step = b.step("parse", "Parse a scene file and print its AST");
    const parse_cmd = b.addRunArtifact(print_ast_exe);
    parse_step.dependOn(&parse_cmd.step);

    if (b.args) |args| {
        parse_cmd.addArgs(args);
    }
}
