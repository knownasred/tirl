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

    const enable_gui = b.option(bool, "gui", "Build the GUI application (requires raylib)") orelse true;

    const run_gui_step = b.step("run-gui", "Run the GUI app");

    if (enable_gui) {
        const raylib_dep = b.dependency("raylib_zig", .{
            .target = target,
            .optimize = optimize,
            .linux_display_backend = .Wayland,
        });

        const gui_exe = b.addExecutable(.{
            .name = "zig_scene_gui",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/gui_main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "zig_scene", .module = mod },
                    .{ .name = "raylib", .module = raylib_dep.module("raylib") },
                },
            }),
            .use_lld = false,
        });
        gui_exe.root_module.linkLibrary(raylib_dep.artifact("raylib"));

        b.installArtifact(gui_exe);

        const run_gui_cmd = b.addRunArtifact(gui_exe);
        if (b.args) |args| {
            run_gui_cmd.addArgs(args);
        }
        run_gui_step.dependOn(&run_gui_cmd.step);
        run_gui_cmd.step.dependOn(b.getInstallStep());
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

    test_step.dependOn(&b.addInstallArtifact(mod_tests, .{ .dest_sub_path = "tsome-test" }).step);

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

    const web_exe = b.addExecutable(.{
        .name = "zig_scene_web",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/web_main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zig_scene", .module = mod },
            },
        }),
    });

    b.installArtifact(web_exe);

    const run_web_step = b.step("run-web", "Run the web server");
    const run_web_cmd = b.addRunArtifact(web_exe);
    run_web_step.dependOn(&run_web_cmd.step);
    run_web_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_web_cmd.addArgs(args);
    }
}
