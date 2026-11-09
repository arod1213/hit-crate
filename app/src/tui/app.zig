const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const lib = @import("lib");
const miniaudio = lib.miniaudio;

const Mode = enum { search, explore };
const ActiveParam = enum { centroid, width };

idx: usize,
mode: Mode = .explore,
active_param: ActiveParam = .centroid,
search_text: std.ArrayList(u8),
params: lib.SearchParams,

engine: [*c]miniaudio.ma_engine,
sound: ?[*c]miniaudio.ma_sound = null,
samples: []lib.SampleEntry,

target_lufs: f32 = -17.0,
limit: usize,
page: usize,

const Self = @This();

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
