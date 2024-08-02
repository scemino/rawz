const std = @import("std");
const Build = std.Build;
const ResolvedTarget = Build.ResolvedTarget;
const Module = Build.Module;
const OptimizeMode = std.builtin.OptimizeMode;

pub const Options = struct {
    src_dir: []const u8,
    target: ResolvedTarget,
    optimize: OptimizeMode,
    mod_raw: *Module,
};

pub fn build(b: *Build, options: Options) void {
    const exe = b.addExecutable(.{
        .name = "disasm",
        .root_source_file = b.path(b.fmt("{s}/disasm/main.zig", .{options.src_dir})),
        .target = options.target,
        .optimize = options.optimize,
    });
    exe.root_module.addImport("raw", options.mod_raw);
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    b.step("run-disasm", "Run the disassembler").dependOn(&run.step);
}
