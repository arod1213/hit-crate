const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const lib = @import("lib");

const Slots = @import("slot_list.zig");

const Mode = union(enum) {
    search, // create search text
    explore, // look through list of samples
    push, // push selected sample to sequencer
    track: usize,
    kit_generate, // create random kit
};
const ActiveParam = enum { centroid, width, pitch };

// add +1 for selected track output
pub const NUM_VOICES = 4 + 1;

/// used for samples + general UI
mu: Io.Mutex = .init,
db_conn: lib.db.Connection,
engine: lib.ma.Engine,
// used to render list of matching samples
samples: []lib.SampleEntry,
// used for drum kit playback
sample_slots: Slots.init(NUM_VOICES) = .{},

search_text: std.ArrayList(u8),
midi_ctx: lib.midi.MidiCtx,
params: lib.SearchParams,

idx: usize,
mode: Mode = .{ .explore = {} },
active_param: ActiveParam = .centroid,
pitch_semitones: i32 = 0,
target_lufs: f32 = -17.0,
limit: usize,
page: usize,

const Self = @This();

pub fn resetSearch(self: *Self, gpa: Allocator) void {
    self.search_text.clearAndFree(gpa);
    self.params.search_text = self.search_text.items;
}

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
