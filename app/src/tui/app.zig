const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("lib");
const ma = lib.miniaudio;

idx: usize,
engine: [*c]ma.ma_engine,
sound: ?[*c]ma.ma_sound = null,
samples: []lib.SampleEntry,

target_lufs: f32 = -17.0,
params: lib.SearchParams,
limit: usize,
page: usize,

const Self = @This();
pub fn next(self: *Self) void {
    if (self.samples.len == 0) return;
    if (self.idx >= self.samples.len - 1) return;
    self.idx +|= 1;
}

pub fn prev(self: *Self) void {
    self.idx -|= 1;
}

pub fn currFile(self: Self) ?lib.SampleEntry {
    if (self.samples.len == 0) return null;
    if (self.idx >= self.samples.len) return null;
    return self.samples[self.idx];
}
