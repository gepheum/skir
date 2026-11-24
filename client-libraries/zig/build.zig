const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .name = "skir_client",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/skir_client.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });

    b.installArtifact(lib);

    // Expose as a Zig module so dependents can `@import` it via the package
    // manager without additional build configuration.
    const skir_client_mod = b.addModule("skir_client", .{
        .root_source_file = b.path("src/skir_client.zig"),
        .target = target,
        .optimize = optimize,
    });
    _ = skir_client_mod;

    // Tests
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/skir_client.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Docs
    const docs_step = b.step("docs", "Build documentation");
    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);
}
