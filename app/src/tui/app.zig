const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const lib = @import("lib");
const Slot = @import("slot.zig");

const Mode = enum {
    search, // create search text
    explore, // look through list of samples
    push, // push selected sample to sequencer
};
const ActiveParam = enum { centroid, width, pitch };

pub const NUM_VOICES = 4;

mu: Io.Mutex = .init,
engine: lib.ma.Engine,
// used to render list of matching samples
samples: []lib.SampleEntry,
// used for drum kit playback
sequencer_samples: [NUM_VOICES]?Slot = std.mem.zeroes([NUM_VOICES]?Slot),

search_text: std.ArrayList(u8),
midi_ctx: lib.midi.MidiCtx,
params: lib.SearchParams,

idx: usize,
mode: Mode = .explore,
active_param: ActiveParam = .centroid,
pitch_semitones: i32 = 0,
target_lufs: f32 = -17.0,
limit: usize,
page: usize,

const Self = @This();

pub fn setPitch(self: *Self, semitones: i32) void {
    const clipped = @max(-36, @min(36, semitones));
    self.pitch_semitones = clipped;
}

pub fn nextPage(self: *Self) bool {
    if (self.samples.len == 0 or self.samples.len < self.limit) return false;
    self.page +|= 1;
    self.idx = 0;
    return true;
}

/// returns if paginated
pub fn prevPage(self: *Self) bool {
    if (self.page == 0) return false;
    self.page -|= 1;
    self.idx = 0;
    return true;
}

/// returns if paginated
pub fn next(self: *Self) bool {
    if (self.samples.len == 0) return false;
    if (self.idx >= self.samples.len - 1) {
        return self.nextPage();
    }
    self.idx +|= 1;
    return false;
}

pub fn prev(self: *Self) bool {
    if (self.idx == 0 and self.page > 0) {
        self.idx = self.limit;
        return self.prevPage();
    }
    self.idx -|= 1;
    return false;
}

pub fn currFile(self: Self) ?lib.SampleEntry {
    if (self.samples.len == 0) return null;
    if (self.idx >= self.samples.len) return null;
    return self.samples[self.idx];
}

pub fn sequencerSample(self: Self, idx: usize) ?Slot {
    if (idx >= self.sequencer_samples.len) return null;
    return self.sequencer_samples[idx];
}
