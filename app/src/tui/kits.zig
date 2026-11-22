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
    assert(app.sample_slots.slots.len > 3);

    const rand: std.Random.IoSource = .{ .io = io };
    const rand_int = rand.interface().int(u16);
    const rand_percent = @mod(
        @as(f32, @floatFromInt(rand_int)),
        100.0,
    );
    std.log.debug("rand is {d:.2}", .{rand_percent});

    const kick_centroid: lib.Slider = .{
        .floor = @min(1_500, app.params.centroid.floor),
        .ceiling = 4_000,
        .exp_scale = 1,
        .tolerance_percent = 5,
        .slider_pos_percent = rand_percent,
    };
    const snare_centroid: lib.Slider = .{
        .floor = 200,
        .ceiling = @max(300, app.params.centroid.ceiling),
        .exp_scale = 1,
        .tolerance_percent = 5,
        .slider_pos_percent = rand_percent,
    };
    const rim_centroid: lib.Slider = .{
        .floor = 400,
        .ceiling = @max(500, app.params.centroid.ceiling),
        .exp_scale = 1,
        .tolerance_percent = 5,
        .slider_pos_percent = rand_percent,
    };
    const hat_centroid: lib.Slider = .{
        .floor = 2_000,
        .ceiling = 12_000,
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
                .centroid = kick_centroid,
                .order_by = .centroid,
                .order_asc = true,
            },
            .{
                .search_text = "rim",
                .duration_ms_max = 1_000,
                .width = app.params.width,
                .centroid = rim_centroid,
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
                .centroid = kick_centroid,
                .order_by = .centroid,
                .order_asc = true,
            },
            .{
                .search_text = "808 sn",
                .duration_ms_max = 1000,
                .width = app.params.width,
                .centroid = snare_centroid,
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

    if (kick) |k| {
        try clearAndSaveSound(io, gpa, app, 0, k);
    }
    if (snare) |s| {
        try clearAndSaveSound(io, gpa, app, 1, s);
    }
    if (hat) |h| {
        try clearAndSaveSound(io, gpa, app, 2, h);
    }
}

pub fn clearAndSaveSound(io: Io, gpa: Allocator, app: *App, idx: usize, sample: lib.SampleEntry) !void {
    // block cleanups past sound
    {
        try app.sample_slots.clearSlot(io, gpa, idx);
    }

    var slot = try Slot.fromSampleEntry(gpa, sample, app.engine.ptr);

    slot.pitch_offset = @floatFromInt(app.pitch_semitones);
    const amp = slot.ampToLufs(app.target_lufs);
    slot.gain_db = lib.audio.ampToDb(f32, amp);
    slot.sound.setGain(amp);

    _ = try app.sample_slots.replace(
        io,
        idx,
        slot,
    );
}
