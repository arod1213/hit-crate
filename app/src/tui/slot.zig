const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("lib");

fullpath: []const u8,
sound: lib.ma.Sound,

const Self = @This();
pub fn deinitOwned(self: Self, gpa: Allocator) void {
    self.sound.deinit(gpa);
    gpa.free(self.fullpath);
    // gpa.free(self.sound.ptr);
}
