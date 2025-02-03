const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    {
        const so = b.addSharedLibrary(.{
            .name = "cricket",
            .target = target,
            .root_source_file = b.path("src/main.zig"),
            .optimize = optimize,
            .link_libc = true,
        });
        so.linkSystemLibrary("mpv");
        b.installArtifact(so);
    }
}
