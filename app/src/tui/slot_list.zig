const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const Slot = @import("slot.zig");

pub fn init(comptime voices: usize) type {
    return struct {
        const Self = @This();

        const VOICES = voices;

        slots: [voices]?Slot = std.mem.zeroes([voices]?Slot),
        mu: std.Io.Mutex = .init,

        pub fn deinit(self: *@This(), io: Io, gpa: Allocator) void {
            self.mu.lockUncancelable(io);
            defer self.mu.unlock(io);

            for (self.slots) |sample| {
                if (sample) |s| {
                    s.deinitOwned(gpa);
                }
            }
        }

        pub fn isEmpty(self: *Self, io: Io, idx: usize) !bool {
            try self.mu.lock(io);
            defer self.mu.unlock(io);
            if (idx >= self.slots.len) return error.OutOfBounds;
            return self.slots[idx] == null;
        }

        pub fn clearSlot(self: *Self, io: Io, gpa: Allocator, idx: usize) !void {
            try self.mu.lock(io);
            defer self.mu.unlock(io);
            if (idx >= self.slots.len) return error.OutOfBounds;
            if (self.slots[idx]) |*s| {
                s.deinitOwned(gpa);
                self.slots[idx] = null;
            }
        }

        pub fn update(self: *Self, io: Io, idx: usize, ctx: anytype, comptime f: fn (@TypeOf(ctx), *Slot) void) !void {
            try self.mu.lock(io);
            defer self.mu.unlock(io);
            if (idx >= self.slots.len) return error.OutOfBounds;
            if (self.slots[idx]) |*s| f(ctx, s);
        }

        pub fn replace(self: *Self, io: Io, idx: usize, new: Slot) !?Slot {
            try self.mu.lock(io);
            defer self.mu.unlock(io);
            if (idx >= self.slots.len) return error.OutOfBounds;
            const old = self.slots[idx];
            self.slots[idx] = new;
            return old;
        }
    };
}
