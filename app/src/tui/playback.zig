const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const lib = @import("lib");

pub const App = @import("app.zig");
// NOTE: not needed yet, but could be nice for midi controller encoder controller
// const sync = @import("sync.zig");
// const CommandType = sync.CommandType;

pub const SELECTED_PLAYBACK_CHAN = 255;
const PLAYBACK_CHANNEL_COUNT = App.NUM_VOICES + 1;
const ROOT_MIDI_NOTE = 60;

pub fn listen(gpa: Allocator, io: Io, app: *App) void {
    var sounds = std.mem.zeroes([PLAYBACK_CHANNEL_COUNT]?lib.ma.Sound);
    defer {
        for (sounds) |sound| {
            if (sound) |snd| {
                snd.stop() catch {};
                snd.deinit(gpa);
            }
        }
    }

    while (true) {
        renderLoop(gpa, io, app, &sounds) catch |e| {
            switch (e) {
                Io.Cancelable.Canceled => return,
                else => {
                    continue;
                },
            }
        };
    }
}

/// create new sound on each playback trigger
/// TODO: check if sound.fullpath == new path and if so keep the active sound
fn renderLoop(gpa: Allocator, io: Io, app: *App, sounds: *[PLAYBACK_CHANNEL_COUNT]?lib.ma.Sound) !void {
    assert(sounds.*.len > 0);

    const event: lib.midi.MidiEvent = app.midi_ctx.queue.getOne(io) catch |e| {
        std.log.err("failed to get MIDI note {}", .{e});
        return e;
    };
    if (!event.isNoteOn()) return;
    const pitch: i32 = @as(i32, @intCast(event.note)) -| @as(i32, @intCast(60));

    switch (event.channel()) {
        SELECTED_PLAYBACK_CHAN => {
            // last buffer idx is selected chan
            const selected_chan = &sounds[sounds.len - 1];
            if (selected_chan.*) |snd| {
                try snd.stop();
                snd.deinit(gpa);
            }

            try app.mu.lock(io);
            defer app.mu.unlock(io);
            const sample = app.currFile() orelse return;
            const amp = sample.ampToLufs(app.target_lufs);

            try play(gpa, app, selected_chan, sample, @floatFromInt(pitch), amp);
        },
        // Sequencer playback
        else => {
            if (event.note < ROOT_MIDI_NOTE) return;
            const playback_chan = event.note - ROOT_MIDI_NOTE;
            if (playback_chan >= PLAYBACK_CHANNEL_COUNT) return; // out of bounds

            const selected_chan = &sounds[@intCast(playback_chan)];
            if (selected_chan.*) |snd| {
                try snd.stop();
                snd.deinit(gpa);
            }

            try app.mu.lock(io);
            defer app.mu.unlock(io);
            const sample = app.sequencerSample(@intCast(playback_chan)) orelse return;
            const amp = sample.ampToLufs(app.target_lufs);

            try play(gpa, app, selected_chan, sample, 0, amp);
        },
    }
}

fn play(gpa: Allocator, app: *App, sound: *?lib.ma.Sound, sample: lib.SampleEntry, pitch: f32, amp: f32) !void {
    const cstr = try gpa.dupeSentinel(u8, sample.fullpath, 0);
    defer gpa.free(cstr);

    sound.* = try lib.ma.Sound.init(gpa, app.engine.ptr, cstr);
    sound.*.?.setGain(amp);

    const snd = sound.* orelse return;

    try snd.stop();
    try snd.seek(0);
    snd.setPitch(pitch);
    try snd.play();
}
