const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("lib");

pub const App = @import("app.zig");
// NOTE: not needed yet, but could be nice for midi controller encoder controller
// const sync = @import("sync.zig");
// const CommandType = sync.CommandType;

pub fn listen(gpa: Allocator, io: Io, app: *App) void {
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

/// create new sound on each playback trigger
/// TODO: check if sound.fullpath == new path and if so keep the active sound
fn renderLoop(gpa: Allocator, io: Io, app: *App, sound: *?lib.ma.Sound) !void {
    const event: lib.midi.MidiEvent = app.midi_ctx.queue.getOne(io) catch |e| {
        std.log.err("failed to get MIDI note {}", .{e});
        return e;
    };
    if (!event.isNoteOn()) return;
    const pitch: i32 = @as(i32, @intCast(event.note)) -| @as(i32, @intCast(60));

    if (sound.*) |snd| {
        try snd.stop();
        snd.deinit(gpa);
    }

    try app.mu.lock(io);
    defer app.mu.unlock(io);
    const curr = app.currFile() orelse return;
    const cstr = try gpa.dupeSentinel(u8, curr.fullpath, 0);
    defer gpa.free(cstr);
    const amp = curr.ampToLufs(app.target_lufs);

    sound.* = try lib.ma.Sound.init(gpa, app.engine.ptr, cstr);
    sound.*.?.setGain(amp);

    const s = sound.* orelse return;

    try s.stop();
    try s.seek(0);
    s.setPitch(@floatFromInt(pitch));
    try s.play();
}
