const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("lib");

pub const App = @import("app.zig");

pub fn playbackQueue(gpa: Allocator, io: Io, app: *App) void {
    var sound: ?lib.ma.Sound = null;
    defer if (sound) |snd| {
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
    // std.log.info("checking vel {d} and note {d} event {d}", .{ event.velocity, event.note, event.event });
    if (!event.isNoteOn()) return;
    // std.log.info("passed", .{});

    const pitch = event.note -| 60;

    if (app.pending_sound.swap(null, .acq_rel)) |p| {
        // std.log.debug("SOUND FOUND", .{});
        defer {
            gpa.free(p.path);
            gpa.destroy(p);
        }
        if (sound.*) |s| s.deinit(gpa);
        sound.* = lib.ma.Sound.init(gpa, app.engine.ptr, p.path) catch null;
        // if (sound) |s| s.setGain(p.gain);
    } else {
        // std.log.debug("NO pending sound", .{});
    }

    const s = sound.* orelse {
        // std.log.debug("NO SOUND AGAIN", .{});
        return;
    };
    // s.stop() catch continue;
    try s.seek(0);
    try s.play(pitch);
}
