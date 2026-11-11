const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const lib = @import("lib");

const Mode = enum { search, explore };
const ActiveParam = enum { centroid, width, pitch };
const Pending = struct { path: [:0]const u8, amp: f32 };

idx: usize,
mode: Mode = .explore,
active_param: ActiveParam = .centroid,
search_text: std.ArrayList(u8),
params: lib.SearchParams,

mu: Io.Mutex = .init,
engine: lib.ma.Engine,
pending_sound: std.atomic.Value(?*Pending) = .init(null),
samples: []lib.SampleEntry,
midi_ctx: lib.midi.MidiCtx,

pitch_semitones: u8 = 0,
target_lufs: f32 = -17.0,
limit: usize,
page: usize,

const Self = @This();

pub fn publishSelection(self: *Self, gpa: Allocator) !void {
    const curr = self.currFile() orelse return;

    const p = try gpa.create(Pending);
    errdefer gpa.destroy(p);

    const path = try gpa.dupeSentinel(u8, curr.fullpath, 0);
    errdefer gpa.free(path);

    const amp = curr.ampToLufs(self.target_lufs);
    p.* = .{ .path = path, .amp = amp };

    if (self.pending_sound.swap(p, .acq_rel)) |stale| {
        gpa.free(stale.path);
        gpa.destroy(stale);
    }
}

/// TODO: deprecate this as this doesnt work anymore
pub fn setPitch(self: *Self, semitones: u8) void {
    self.pitch_semitones = semitones;
    // if (self.sound != null) {
    //     self.sound.?.setPitch(semitones);
    // }
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
