const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const skir_client_dep = b.dependency("skir_client", .{
        .target = target,
        .optimize = optimize,
    });
    const skir_client_mod = skir_client_dep.module("skir_client");

    const lib_root_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_root_module.addImport("skir_client", skir_client_mod);

    const lib = b.addLibrary(.{
        .name = "e2e_test",
        .root_module = lib_root_module,
        .linkage = .static,
    });

    b.installArtifact(lib);

    const unit_tests_root_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    unit_tests_root_module.addImport("skir_client", skir_client_mod);

    const unit_tests = b.addTest(.{ .root_module = unit_tests_root_module });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // golden tests
    const golden_tests_root_module = b.createModule(.{
        .root_source_file = b.path("src/goldens_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    golden_tests_root_module.addImport("skir_client", skir_client_mod);

    const golden_tests = b.addTest(.{ .root_module = golden_tests_root_module });

    const run_golden_tests = b.addRunArtifact(golden_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_golden_tests.step);
}
