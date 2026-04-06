const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "compiler",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run compiler");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const lister = b.addExecutable(.{
        .name = "lister",
        .root_module = b.createModule(.{
            .link_libc = true,
            .target = target,
            .optimize = optimize,
        }),
    });
    lister.root_module.addIncludePath(b.path("lister"));
    lister.root_module.addCSourceFiles(.{
        .root = b.path("lister"),
        .files = &.{"lister.c"},
    });
    b.installArtifact(lister);

    const lister_step = b.step("lister", "Run lister");
    const lister_cmd = b.addRunArtifact(lister);
    lister_step.dependOn(&lister_cmd.step);
    lister_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| lister_cmd.addArgs(args);
}
