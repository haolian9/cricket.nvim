const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    {
        const lib = b.addSharedLibrary("cricket", "src/main.zig", .unversioned);
        lib.setBuildMode(mode);
        lib.linkLibC();
        lib.linkSystemLibrary("mpv");
        lib.install();
    }

    {
        const main_tests = b.addTest("src/main.zig");
        main_tests.setBuildMode(mode);

        const test_step = b.step("test", "Run library tests");
        test_step.dependOn(&main_tests.step);
    }

    const exe = b.addExecutable("simple", "src/simple.zig");
    {
        exe.setBuildMode(mode);
        exe.linkLibC();
        exe.linkSystemLibrary("mpv");
        exe.strip = false;
        exe.install();
    }

    {
        const run_step = b.step("run", "run simple");
        run_step.dependOn(&exe.run().step);
    }
}
