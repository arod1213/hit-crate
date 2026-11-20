const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const coremidi = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("./include/coremidi.h"),
        .link_libc = false,
    });
    const coremidi_mod = coremidi.createModule();
    coremidi_mod.linkFramework("CoreFoundation", .{});
    coremidi_mod.linkFramework("CoreMIDI", .{ .needed = true });
    if (target.result.os.tag == .macos) {
        const sdk = std.mem.trimEnd(u8, b.run(&.{ "xcrun", "--sdk", "macosx", "--show-sdk-path" }), "\n");
        coremidi_mod.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "System/Library/Frameworks" }) });
        coremidi_mod.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "usr/include" }) });
        coremidi_mod.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "usr/lib" }) });
    }

    const sqlite = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("./include/sqlite3.h"),
        .link_libc = false,
    });
    const sqlite_mod = sqlite.createModule();
    sqlite_mod.addCSourceFile(.{
        .file = b.path("include/sqlite3.c"),
        .language = .c,
        .flags = &[_][]const u8{
            "-DSQLITE_ENABLE_FTS5",
        },
    });

    const kissfft = b.addTranslateC(.{
        .root_source_file = b.path("include/kissfft/kiss_fft.h"),
        .optimize = optimize,
        .target = target,
        .link_libc = true,
    });
    const kissfft_mod = kissfft.createModule();
    kissfft_mod.addCSourceFile(.{
        .file = b.path("include/kissfft/kiss_fft.c"),
    });

    const ebur128 = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("./include/ebur128.h"),
        .link_libc = false,
    });
    const ebur128_mod = ebur128.createModule();
    ebur128_mod.addCSourceFile(.{
        .file = b.path("include/ebur128.c"),
        .language = .c,
    });

    const miniaudio = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("./include/miniaudio.h"),
        .link_libc = false,
    });
    const miniaudio_mod = miniaudio.createModule();
    miniaudio_mod.addCSourceFile(.{
        .file = b.path("include/miniaudio.c"),
        .language = .c,
    });

    if (target.result.os.tag == .macos) {
        // Cross-arch builds don't auto-detect the SDK, so point at it directly.
        const sdk = std.mem.trimEnd(u8, b.run(&.{ "xcrun", "--sdk", "macosx", "--show-sdk-path" }), "\n");
        miniaudio_mod.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "System/Library/Frameworks" }) });
        miniaudio_mod.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "usr/include" }) });
        miniaudio_mod.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "usr/lib" }) });
    }
    miniaudio_mod.linkFramework("CoreFoundation", .{});
    miniaudio_mod.linkFramework("CoreAudio", .{});
    miniaudio_mod.linkFramework("AudioToolbox", .{});

    const mod = b.addModule("zigs", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .link_libc = true,
        .imports = &.{
            .{ .name = "miniaudio", .module = miniaudio_mod },
            .{ .name = "sqlite", .module = sqlite_mod },
            .{ .name = "ebur128", .module = ebur128_mod },
            .{ .name = "kissfft", .module = kissfft_mod },
            .{ .name = "coremidi", .module = coremidi_mod },
        },
    });

    const tui = b.createModule(.{
        .root_source_file = b.path("src/tui/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "lib", .module = mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "zigs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zigs", .module = mod },
                .{ .name = "tui", .module = tui },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

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
}
