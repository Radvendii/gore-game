const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "gore_game",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    exe.linkSystemLibrary("opengl");
    exe.linkLibC();

    // TODO: update SDL.zig to use modern module system
    const sdl = @import("sdl");
    const sdl_sdk = sdl.init(b, .{});
    sdl_sdk.link(exe, .dynamic, sdl.Library.SDL2);
    exe.root_module.addImport("sdl", sdl_sdk.getWrapperModule());

    const zgl = b.dependency("zgl", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zgl", zgl.module("zgl"));

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    { // shouldn't need to be this repetitive
        const exe_check = b.addExecutable(.{
            .name = "gore_game",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{},
            }),
        });

        exe_check.linkSystemLibrary("opengl");
        exe_check.linkLibC();

        // TODO: update SDL.zig to use modern module system
        const sdl_sdk_2 = sdl.init(b, .{});
        sdl_sdk_2.link(exe_check, .dynamic, sdl.Library.SDL2);
        exe_check.root_module.addImport("sdl", sdl_sdk.getWrapperModule());

        exe_check.root_module.addImport("zgl", zgl.module("zgl"));

        const check = b.step("check", "For zls");
        check.dependOn(&exe_check.step);
    }

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
