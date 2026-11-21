const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const lib = @import("lib");

pub const App = @import("app.zig");
pub const input = @import("input.zig");
const kits = @import("kits.zig");
pub const playback = @import("playback.zig");
const Slot = @import("slot.zig");
const sync = @import("sync.zig");
const CommandType = sync.CommandType;

pub fn listen(io: Io, gpa: Allocator, app: *App, rdr: *Io.Reader, cmd_queue: *sync.CommandQueue) void {
    while (true) {
        handleKey(io, gpa, app, rdr, cmd_queue) catch |e| {
            switch (e) {
                Io.Cancelable.Canceled => return,
                else => {
                    std.log.err("err reading keys: {}", .{e});
                    continue;
                },
            }
        };
    }
}

/// ensure reading occurs before mutex is acquired
fn handleKey(io: Io, gpa: Allocator, app: *App, rdr: *Io.Reader, cmd_queue: *sync.CommandQueue) !void {
    if (app.mode == .search) {
        const byte = try rdr.takeByte();
        const cmd = try handleSearch(io, gpa, app, byte);
        try cmd_queue.putOne(io, cmd);
        return;
    }

    const key = try input.KeyCode.parse(rdr) orelse .unknown;

    // mutex on app acquired here
    const cmd_type: CommandType = switch (app.mode) {
        .search => unreachable, // handled above
        .explore => try handleExplore(io, gpa, app, key),
        .push => try handlePush(io, gpa, app, key),
        .track => |idx| try handleTrack(io, app, key, idx),
        .kit_generate => try handleKit(io, gpa, app, key),
    };
    try cmd_queue.putOne(io, cmd_type);
}

fn handleKit(io: Io, gpa: Allocator, app: *App, key: input.KeyCode) !CommandType {
    defer app.mode = .explore;

    // lock is acquired in the generation
    switch (key) {
        .@"1" => try kits.generateKit(io, gpa, .default, app),
        .@"2" => try kits.generateKit(io, gpa, .rnb, app),
        .@"3" => try kits.generateKit(io, gpa, .rap, app),
        else => try kits.generateKit(io, gpa, .default, app),
    }
    return .key;
}

fn handleTrack(io: Io, app: *App, key: input.KeyCode, curr_idx: usize) !CommandType {
    const max_idx = if (app.sequencer_samples.len == 0) 0 else app.sequencer_samples.len - 1;
    const sample = &app.sequencer_samples[curr_idx];

    try app.mu.lock(io);
    defer app.mu.unlock(io);
    switch (key) {
        .space => {
            const midi_shift = playback.ROOT_MIDI_NOTE +| curr_idx;
            const midi_note: i32 = @max(
                0,
                @min(std.math.maxInt(u8), midi_shift),
            );

            try app.midi_ctx.queue.putOne(
                io,
                lib.midi.MidiEvent.noteOn(
                    1, // chan
                    @intCast(midi_note),
                    Io.Clock.now(.awake, io).toNanoseconds(),
                ),
            );
        },
        .period => {
            if (app.sequencer_samples[curr_idx]) |*curr| {
                const val = curr.start_offset_ms + 1;
                curr.start_offset_ms = @min(200, val);
            }
        },
        .comma => {
            if (app.sequencer_samples[curr_idx]) |*curr| {
                const val = curr.start_offset_ms - 1;
                curr.start_offset_ms = @max(0.0, val);
            }
        },
        .left => app.mode = .{ .track = curr_idx -| 1 },
        .right => app.mode = .{ .track = @min(curr_idx + 1, max_idx) },
        .tab => app.mode = .{ .explore = {} },
        .@"1" => {
            if (sample.*) |*s| {
                s.pitch_offset -= 1.0;
            }
        },
        .@"2" => {
            if (sample.*) |*s| {
                s.pitch_offset += 1.0;
            }
        },
        .down => {
            if (sample.*) |*s| {
                s.gain_db -= 1.0;
            }
        },
        .up => {
            if (sample.*) |*s| {
                s.gain_db += 1.0;
            }
        },
        else => return .no_op,
    }
    return .key;
}

fn handleSearch(io: Io, gpa: Allocator, app: *App, b: u8) !CommandType {
    try app.mu.lock(io);
    defer app.mu.unlock(io);
    switch (b) {
        '\n', '\r', 0x1B => {
            app.mode = .explore;
            return .key;
        },
        0x7F, 0x08 => _ = {
            _ = app.search_text.pop();
            app.page = 0;
            app.idx = 0;
        },
        else => {
            try app.search_text.append(gpa, b);
            app.page = 0;
            app.idx = 0;
        },
    }
    app.params.search_text = app.search_text.items;
    return .fetch;
}

/// TODO: this curr value will be freed so needs a new alloc or to be copied
fn handlePush(io: Io, gpa: Allocator, app: *App, key: input.KeyCode) !CommandType {
    defer app.mode = .explore; // leave mode

    const curr = app.currFile() orelse return .no_op;

    const idx: u8 = switch (key) {
        .@"1" => 0,
        .@"2" => 1,
        .@"3" => 2,
        .@"4" => 3,
        // .@"5" => 4,
        // .@"6" => 5,
        // .@"7" => 6,
        // .@"8" => 7,
        else => return .key,
    };
    assert(idx < App.NUM_VOICES);

    try app.mu.lock(io);
    defer app.mu.unlock(io);
    try kits.clearAndSaveSound(gpa, app, idx, curr);
    return .key;
}

fn handleExplore(io: Io, gpa: Allocator, app: *App, key: input.KeyCode) !CommandType {
    try app.mu.lock(io);
    defer app.mu.unlock(io);

    var cmd_type: CommandType = .key;
    switch (key) {
        // MODES
        .back_slash => {
            app.mode = .search;
        },
        .p => {
            app.mode = .push;
        },
        .k => {
            app.mode = .kit_generate;
        },
        .tab => {
            app.mode = .{ .track = 0 };
            return .key;
        },
        // PARAMS
        .@"1" => {
            switch (app.active_param) {
                .centroid => app.params.centroid.moveLeft(5),
                .width => app.params.width.moveLeft(5),
                .pitch => app.setPitch(app.pitch_semitones - 1),
            }
            cmd_type = .fetch;
        },
        .@"2" => {
            switch (app.active_param) {
                .centroid => app.params.centroid.moveRight(5),
                .width => app.params.width.moveRight(5),
                .pitch => app.setPitch(app.pitch_semitones + 1),
            }
            cmd_type = .fetch;
        },
        .@"3" => {
            switch (app.active_param) {
                .centroid => app.params.centroid.moveTolerance(-5),
                .width => app.params.width.moveTolerance(-5),
                .pitch => {},
            }
            cmd_type = .fetch;
        },
        .@"4" => {
            switch (app.active_param) {
                .centroid => app.params.centroid.moveTolerance(5),
                .width => app.params.width.moveTolerance(5),
                .pitch => {},
            }
            cmd_type = .fetch;
        },
        ////////////////
        // FILTERs
        ////////////////
        .o => { // change order direction
            app.params.order_asc = !app.params.order_asc;
            app.page = 0;
            cmd_type = .fetch;
        },
        .m => { // toggle order mode
            app.params.order_by = switch (app.params.order_by) {
                .width => .centroid,
                .name => .width,
                .centroid => .name,
            };
            app.page = 0;
            cmd_type = .fetch;
        },
        .r => { // reset
            app.resetSearch(gpa);
            app.pitch_semitones = 0;
            app.params = .{
                .search_text = app.search_text.items,
            };
            app.page = 0;
            cmd_type = .fetch;
        },
        .s => { // find similar
            if (app.currFile()) |curr| {
                app.resetSearch(gpa);

                if (curr.centroid) |x| {
                    std.log.info("centroid is {}", .{x});
                    app.params.centroid.setValue(x) catch |e| {
                        std.log.err("err setting value: {}", .{e});
                    };
                    app.params.centroid.tolerance_percent = 2;
                }
                std.log.info("width is {}", .{curr.width});
                app.params.width.setValue(curr.width) catch {};
                app.params.width.tolerance_percent = 2;
                app.page = 0;
                cmd_type = .fetch;
            }
        },
        .a => { // toggle active
            app.active_param = switch (app.active_param) {
                .centroid => .width,
                .width => .pitch,
                .pitch => .centroid,
            };
        },
        .y => { // open selected
            const curr = app.currFile() orelse return .no_op;
            try lib.revealFile(io, curr.fullpath);
            for (app.sequencer_samples) |sample| {
                if (sample) |s| {
                    try lib.revealFile(io, s.fullpath);
                }
            }
        },
        ////////////////
        // General
        ////////////////
        .down => { // cursor down
            if (app.next()) cmd_type = .fetch;
        },
        .up => { // cursor up
            if (app.prev()) cmd_type = .fetch;
        },
        .right => { // page next
            if (app.nextPage()) cmd_type = .fetch;
        },
        .left => { // page prev
            if (app.prevPage()) cmd_type = .fetch;
        },
        .space => { // play selected
            const sample = app.currFile() orelse return .no_op;

            assert(app.sequencer_samples.len > 0);
            const idx = app.sequencer_samples.len - 1;
            try kits.clearAndSaveSound(
                gpa,
                app,
                idx,
                sample,
            );
            assert(app.sequencer_samples[idx] != null);

            const midi_shift = playback.ROOT_MIDI_NOTE +| app.pitch_semitones;
            const midi_note: i32 = @max(
                0,
                @min(std.math.maxInt(u8), midi_shift),
            );

            try app.midi_ctx.queue.putOne(
                io,
                lib.midi.MidiEvent.noteOn(
                    playback.SELECTED_PLAYBACK_CHAN,
                    @intCast(midi_note),
                    Io.Clock.now(.awake, io).toNanoseconds(),
                ),
            );
        },
        else => return .no_op,
    }
    return cmd_type;
}

fn sendMidiPlay(io: Io, app: *const App, idx: usize) !void {
    const midi_shift = 60 +| app.pitch_semitones;
    const midi_note: i32 = @max(
        0,
        @min(std.math.maxInt(u8), midi_shift),
    );

    try app.midi_ctx.queue.putOne(
        io,
        lib.midi.MidiEvent.noteOn(
            idx,
            @intCast(midi_note),
            Io.Clock.now(.awake, io).toNanoseconds(),
        ),
    );
}
