const std = @import("std");
const sokol = @import("sokol");
const tools = @import("tools/build.zig");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;
const ResolvedTarget = Build.ResolvedTarget;
const Dependency = Build.Dependency;
const Module = Build.Module;

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // note that the sokol dependency is built with `.with_imgui_sokol = true`
    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
        .with_sokol_imgui = true,
    });
    const dep_cimgui = b.dependency("cimgui", .{
        .target = target,
        .optimize = optimize,
    });
    const mod_common = b.addModule("common", .{
        .root_source_file = b.path("src/common/common.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
        },
    });
    const mod_raw = b.addModule("rawz", .{
        .root_source_file = b.path("src/raw/raw.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "common", .module = mod_common },
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
        },
    });

    // inject the cimgui header search path into the sokol C library compile step
    const cimgui_root = dep_cimgui.namedWriteFiles("cimgui").getDirectory();
    dep_sokol.artifact("sokol_clib").addIncludePath(cimgui_root);

    // from here on different handling for native vs wasm builds
    if (target.result.isWasm()) {
        try buildWasm(b, target, optimize, dep_sokol, dep_cimgui, mod_common, mod_raw);
    } else {
        try buildNative(b, target, optimize, dep_sokol, dep_cimgui, mod_common, mod_raw);
    }
    tools.build(b, .{
        .src_dir = "tools",
        .target = target,
        .optimize = optimize,
        .mod_raw = mod_raw,
    });
}

fn buildNative(b: *Build, target: ResolvedTarget, optimize: OptimizeMode, dep_sokol: *Dependency, dep_cimgui: *Dependency, mod_common: *Module, mod_raw: *Module) !void {
    const exe = b.addExecutable(.{
        .name = "rawz",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const clap = b.dependency("clap", .{});
    exe.root_module.addImport("common", mod_common);
    exe.root_module.addImport("clap", clap.module("clap"));
    exe.root_module.addImport("sokol", dep_sokol.module("sokol"));
    exe.root_module.addImport("cimgui", dep_cimgui.module("cimgui"));
    exe.root_module.addImport("raw", mod_raw);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    b.step("run", "Run exe").dependOn(&run_cmd.step);
}

fn buildWasm(b: *Build, target: ResolvedTarget, optimize: OptimizeMode, dep_sokol: *Dependency, dep_cimgui: *Dependency, mod_common: *Module, mod_raw: *Module) !void {
    // build the main file into a library, this is because the WASM 'exe'
    // needs to be linked in a separate build step with the Emscripten linker
    const exe = b.addStaticLibrary(.{
        .name = "rawz",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const clap = b.dependency("clap", .{});
    exe.root_module.addImport("clap", clap.module("clap"));
    exe.root_module.addImport("common", mod_common);
    exe.root_module.addImport("sokol", dep_sokol.module("sokol"));
    exe.root_module.addImport("cimgui", dep_cimgui.module("cimgui"));
    exe.root_module.addImport("raw", mod_raw);

    // get the Emscripten SDK dependency from the sokol dependency
    const dep_emsdk = dep_sokol.builder.dependency("emsdk", .{});

    // need to inject the Emscripten system header include path into
    // the cimgui C library otherwise the C/C++ code won't find
    // C stdlib headers
    const emsdk_incl_path = dep_emsdk.path("upstream/emscripten/cache/sysroot/include");
    dep_cimgui.artifact("cimgui_clib").addSystemIncludePath(emsdk_incl_path);

    // all C libraries need to depend on the sokol library, when building for
    // WASM this makes sure that the Emscripten SDK has been setup before
    // C compilation is attempted (since the sokol C library depends on the
    // Emscripten SDK setup step)
    dep_cimgui.artifact("cimgui_clib").step.dependOn(&dep_sokol.artifact("sokol_clib").step);

    // create a build step which invokes the Emscripten linker
    const link_step = try sokol.emLinkStep(b, .{
        .lib_main = exe,
        .target = target,
        .optimize = optimize,
        .emsdk = dep_emsdk,
        .use_webgl2 = true,
        .use_emmalloc = true,
        .use_filesystem = false,
        .shell_file_path = dep_sokol.path("src/sokol/web/shell.html").getPath(b),
    });
    // ...and a special run step to start the web build output via 'emrun'
    const run = sokol.emRunStep(b, .{ .name = "rawz", .emsdk = dep_emsdk });
    run.step.dependOn(&link_step.step);
    b.step("run", "Run exe").dependOn(&run.step);
}
