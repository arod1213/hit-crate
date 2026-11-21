const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("lib");

fullpath: []const u8,
sound: lib.ma.Sound,
gain_db: f32 = 0.0,
pitch_offset: f32 = 0.0,
start_offset_ms: f32 = 0.0,
lufs: ?f32,
rms: f32,
true_peak: ?f32,

const Self = @This();

pub fn ampToLufs(self: Self, target_lufs: f32) f32 {
    const rms_amp =
        lib.audio.ampToTarget(f32, self.rms, target_lufs);
    const lufs_amp =
        if (self.lufs) |lufs|
            lib.audio.ampToTarget(f32, lufs, target_lufs)
        else
            1;
    const tp_amp =
        if (self.true_peak) |tp|
            lib.audio.ampToTarget(f32, tp, target_lufs)
        else
            1;
    const avg = (rms_amp + lufs_amp + tp_amp) / 3;
    return @min(2, avg);
}

pub fn deinitOwned(self: Self, gpa: Allocator) void {
    self.sound.deinit(gpa);
    gpa.free(self.fullpath);
    // gpa.free(self.sound.ptr);
}

pub fn fromSampleEntry(gpa: Allocator, sample: lib.SampleEntry, engine: [*c]lib.miniaudio.ma_engine) !Self {
    const fullpath = try gpa.dupe(u8, sample.fullpath);
    errdefer gpa.free(fullpath);

    // only needed to open miniaudio.sound
    const cstr = try gpa.dupeSentinel(u8, sample.fullpath, 0);
    defer gpa.free(cstr);

    return .{
        .pitch_offset = 0,
        .gain_db = 0.0,
        .rms = sample.rms,
        .lufs = sample.lufs,
        .true_peak = sample.true_peak,
        .fullpath = fullpath,
        .sound = try lib.ma.Sound.init(gpa, engine, cstr),
    };
}
