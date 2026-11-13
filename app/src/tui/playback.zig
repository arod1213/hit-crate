const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Slot = @import("slot.zig");
const lib = @import("lib");

pub const App = @import("app.zig");
// NOTE: not needed yet, but could be nice for midi controller encoder controller
// const sync = @import("sync.zig");
// const CommandType = sync.CommandType;

pub const SELECTED_PLAYBACK_CHAN = 15;
const NUM_VOICES = App.NUM_VOICES;
const ROOT_MIDI_NOTE = 60;

pub fn listen(gpa: Allocator, io: Io, app: *App) void {
    while (true) {
        renderLoop(gpa, io, app, &app.sequencer_samples) catch |e| {
            switch (e) {
                Io.Cancelable.Canceled => return,
                else => continue,
            }
        };
    }
}

/// create new sound on each playback trigger
/// TODO: check if sound.fullpath == new path and if so keep the active sound
fn renderLoop(_: Allocator, io: Io, app: *App, slots: *[NUM_VOICES]?Slot) !void {
    assert(slots.*.len > 0);

    const event: lib.midi.MidiEvent = app.midi_ctx.queue.getOne(io) catch |e| {
        std.log.err("failed to get MIDI note {}", .{e});
        return e;
    };
    if (!event.isNoteOn()) return;

    const ch = event.channel();
    const idx: usize = switch (ch) {
        SELECTED_PLAYBACK_CHAN => slots.len - 1,
        else => blk: {
            if (event.note < ROOT_MIDI_NOTE) return error.NoteTooLow;
            const playback_note = event.note - ROOT_MIDI_NOTE;
            if (playback_note >= slots.len) return error.OutOfBounds; // out of bounds
            break :blk @intCast(playback_note);
        },
    };
    if (slots.*[idx]) |s| {
        const start_offset_frames = getSoundStartFrame(io, &app.engine, event.timestamp);
        try s.sound.seek(0);
        s.sound.ptr.set_start_time_in_pcm_frames(start_offset_frames);
        try s.sound.play();
    }
}

const SCHEDULE_LATENCY_NS: i96 = 10 * std.time.ns_per_ms;
fn getSoundStartFrame(io: Io, engine: *const lib.ma.Engine, event_ns: i96) u64 {
    const elapsed_ns = Io.Timestamp.fromNanoseconds(event_ns)
        .untilNow(io, .awake).nanoseconds;
    const delay_ns: i96 = @max(0, SCHEDULE_LATENCY_NS - elapsed_ns);

    const sample_rate: i96 = engine.ptr.get_sample_rate();
    const delay_frames: u64 = @intCast(@divTrunc(delay_ns * sample_rate, std.time.ns_per_s));
    return engine.ptr.get_time_in_pcm_frames() + delay_frames;
}
