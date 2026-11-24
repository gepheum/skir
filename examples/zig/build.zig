const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const skir_client_dep = b.dependency("skir_client", .{
        .target = target,
        .optimize = optimize,
    });
    const skir_client_mod = skir_client_dep.module("skir_client");

    const httpz_dep = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    });
    const httpz_mod = httpz_dep.module("httpz");

    const snippets_root_module = b.createModule(.{
        .root_source_file = b.path("src/snippets.zig"),
        .target = target,
        .optimize = optimize,
    });
    snippets_root_module.addImport("skir_client", skir_client_mod);

    const snippets_exe = b.addExecutable(.{
        .name = "snippets",
        .root_module = snippets_root_module,
    });

    const start_service_root_module = b.createModule(.{
        .root_source_file = b.path("src/start_service.zig"),
        .target = target,
        .optimize = optimize,
    });
    start_service_root_module.addImport("skir_client", skir_client_mod);
    start_service_root_module.addImport("httpz", httpz_mod);

    const start_service_exe = b.addExecutable(.{
        .name = "start-service",
        .root_module = start_service_root_module,
    });

    const call_service_root_module = b.createModule(.{
        .root_source_file = b.path("src/call_service.zig"),
        .target = target,
        .optimize = optimize,
    });
    call_service_root_module.addImport("skir_client", skir_client_mod);

    const call_service_exe = b.addExecutable(.{
        .name = "call-service",
        .root_module = call_service_root_module,
    });

    b.installArtifact(snippets_exe);
    b.installArtifact(start_service_exe);
    b.installArtifact(call_service_exe);

    const run_snippets_cmd = b.addRunArtifact(snippets_exe);
    run_snippets_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_snippets_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the snippets example");
    run_step.dependOn(&run_snippets_cmd.step);

    const run_start_service = b.addRunArtifact(start_service_exe);
    run_start_service.step.dependOn(b.getInstallStep());
    const run_start_service_step = b.step("run-start-service", "Run the SkirRPC service example");
    run_start_service_step.dependOn(&run_start_service.step);

    const run_call_service = b.addRunArtifact(call_service_exe);
    run_call_service.step.dependOn(b.getInstallStep());
    const run_call_service_step = b.step("run-call-service", "Run the SkirRPC client example");
    run_call_service_step.dependOn(&run_call_service.step);

    const unit_tests_root_module = b.createModule(.{
        .root_source_file = b.path("src/snippets.zig"),
        .target = target,
        .optimize = optimize,
    });
    unit_tests_root_module.addImport("skir_client", skir_client_mod);

    const unit_tests = b.addTest(.{ .root_module = unit_tests_root_module });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
