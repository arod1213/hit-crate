const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("lib");

pub const App = @import("app.zig");

pub fn playbackQueue(gpa: Allocator, io: Io, app: *App) void {
    var sound: ?lib.ma.Sound = null;
    defer if (sound) |snd| {
        snd.stop() catch {};
        snd.deinit(gpa);
    };

    while (true) {
        renderLoop(gpa, io, app, &sound) catch |e| {
            switch (e) {
                Io.Cancelable.Canceled => return,
                else => {
                    continue;
                },
            }
        };
    }
}

fn renderLoop(gpa: Allocator, io: Io, app: *App, sound: *?lib.ma.Sound) !void {
    const event: lib.midi.MidiEvent = app.midi_ctx.queue.getOne(io) catch |e| {
        std.log.err("failed to get MIDI note {}", .{e});
        return e;
    };
    if (!event.isNoteOn()) return;

    const pitch: i32 = @as(i32, @intCast(event.note)) -| @as(i32, @intCast(60));

    if (app.pending_sound.swap(null, .acq_rel)) |p| {
        defer {
            gpa.free(p.path);
            gpa.destroy(p);
        }

        if (sound.*) |s| {
            s.stop() catch {};
            s.deinit(gpa);
        }
        sound.* = lib.ma.Sound.init(gpa, app.engine.ptr, p.path) catch null;
    } else {
        // std.log.debug("NO pending sound", .{});
    }

    const s = sound.* orelse {
        // std.log.debug("NO SOUND AGAIN", .{});
        return;
    };
    // s.stop() catch continue;
    try s.seek(0);
    s.setPitch(@floatFromInt(pitch));
    try s.play();
}
