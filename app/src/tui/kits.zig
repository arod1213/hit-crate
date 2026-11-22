const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const lib = @import("lib");

pub const App = @import("app.zig");
pub const NUM_VOICES = App.NUM_VOICES;
const Slot = @import("slot.zig");

const KitType = enum(u8) {
    default = 0,
    rnb,
    rap,
};

pub fn generateKit(io: Io, gpa: Allocator, kit: KitType, app: *App) !void {
    // must have at least voices for kick snare hat
    assert(app.sequencer_samples.len > 3);

    const rand: std.Random.IoSource = .{ .io = io };
    const rand_int = rand.interface().int(u8);
    const rand_percent = @as(f32, @floatFromInt(rand_int)) / 100.0;

    const kick_centroid: lib.Slider = .{
        .floor = @min(1_500, app.params.centroid.floor),
        .ceiling = 2_000,
        .exp_scale = 1,
        .tolerance_percent = 5,
        .slider_pos_percent = rand_percent,
    };
    const snare_centroid: lib.Slider = .{
        .floor = 500,
        .ceiling = @max(700, app.params.centroid.ceiling),
        .exp_scale = 1,
        .tolerance_percent = 5,
        .slider_pos_percent = rand_percent,
    };
    const hat_centroid: lib.Slider = .{
        .floor = 3_000,
        .ceiling = 10_000,
        .exp_scale = 1,
        .tolerance_percent = 5,
        .slider_pos_percent = rand_percent,
    };

    const kick_params, const snare_params, const hat_params = switch (kit) {
        .default => [3]lib.SearchParams{
            .{
                .search_text = "kick",
                .width = app.params.width,
                .centroid = kick_centroid,
                .order_by = .centroid,
                .order_asc = true,
            },
            .{
                .search_text = "snare",
                .duration_ms_max = 1000,
                .width = app.params.width,
                .centroid = snare_centroid,
                .order_by = .centroid,
                .order_asc = false,
            },
            .{
                .search_text = "hat",
                .duration_ms_max = 1200,
                .width = app.params.width,
                .centroid = hat_centroid,
                .order_by = .centroid,
                .order_asc = false,
            },
        },
        .rnb => [3]lib.SearchParams{
            .{
                .search_text = "kick",
                .width = app.params.width,
                .centroid = app.params.centroid,
                .order_by = .centroid,
                .order_asc = true,
            },
            .{
                .search_text = "rim",
                .duration_ms_max = 1000,
                .width = app.params.width,
                .centroid = app.params.centroid,
                .order_by = .centroid,
                .order_asc = false,
            },
            .{
                .search_text = "hat",
                .duration_ms_max = 1000,
                .width = app.params.width,
                .centroid = hat_centroid,
                .order_by = .centroid,
                .order_asc = false,
            },
        },
        .rap => [3]lib.SearchParams{
            .{
                .search_text = "808",
                .width = app.params.width,
                .centroid = app.params.centroid,
                .order_by = .centroid,
                .order_asc = true,
            },
            .{
                .search_text = "808 sn",
                .duration_ms_max = 1000,
                .width = app.params.width,
                .centroid = app.params.centroid,
                .order_by = .centroid,
                .order_asc = false,
            },
            .{
                .search_text = "hat",
                .duration_ms_max = 1000,
                .width = app.params.width,
                .centroid = hat_centroid,
                .order_by = .centroid,
                .order_asc = false,
            },
        },
    };

    // used only to free results from db query
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const kick = try lib.querySample(arena_alloc, app.db_conn, kick_params);
    const snare = try lib.querySample(arena_alloc, app.db_conn, snare_params);
    const hat = try lib.querySample(arena_alloc, app.db_conn, hat_params);

    try app.mu.lock(io);
    defer app.mu.unlock(io);
    if (kick) |k| {
        try clearAndSaveSound(gpa, app, 0, k);
    }
    if (snare) |s| {
        try clearAndSaveSound(gpa, app, 1, s);
    }
    if (hat) |h| {
        try clearAndSaveSound(gpa, app, 2, h);
    }
}

pub fn clearAndSaveSound(gpa: Allocator, app: *App, idx: usize, sample: lib.SampleEntry) !void {
    if (app.sequencer_samples[idx]) |*current| {
        current.deinitOwned(gpa);
    }

    const fullpath = try gpa.dupe(u8, sample.fullpath);
    errdefer gpa.free(fullpath);

    // only needed to open miniaudio.sound
    const cstr = try gpa.dupeSentinel(u8, sample.fullpath, 0);
    defer gpa.free(cstr);

    const seq_sample = &app.sequencer_samples[idx];
    seq_sample.* = try Slot.fromSampleEntry(gpa, sample, app.engine.ptr);
    const amp = seq_sample.*.?.ampToLufs(app.target_lufs);

    assert(seq_sample.* != null);
    seq_sample.*.?.pitch_offset = @floatFromInt(app.pitch_semitones);
    seq_sample.*.?.gain_db = lib.audio.ampToDb(f32, amp);
    seq_sample.*.?.sound.setGain(amp);
}
