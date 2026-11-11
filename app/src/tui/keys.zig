const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const lib = @import("lib");

pub const App = @import("app.zig");
pub const input = @import("input.zig");
pub const playback = @import("playback.zig");
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

fn handleKey(io: Io, gpa: Allocator, app: *App, rdr: *Io.Reader, cmd_queue: *sync.CommandQueue) !void {
    const cmd_type = switch (app.mode) {
        .explore => try handleExplore(io, gpa, app, rdr),
        .search => try handleSearch(io, gpa, app, rdr),
        .push => try handlePush(io, gpa, app, rdr),
    };
    try cmd_queue.putOne(io, cmd_type);
}

fn handleSearch(io: Io, gpa: Allocator, app: *App, rdr: *Io.Reader) !CommandType {
    const b = try rdr.takeByte();

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
fn handlePush(io: Io, gpa: Allocator, app: *App, rdr: *Io.Reader) !CommandType {
    try app.mu.lock(io);
    defer app.mu.unlock(io);
    defer app.mode = .explore; // leave mode

    const key = try input.KeyCode.parse(rdr) orelse return .no_op;
    const curr = app.currFile() orelse return .no_op;

    const idx: u8 = switch (key) {
        .@"1" => 0,
        .@"2" => 1,
        .@"3" => 2,
        .@"4" => 3,
        else => return .key,
    };
    assert(idx < App.NUM_VOICES);

    if (app.sequencer_samples[idx]) |sample| {
        sample.deinitOwned(gpa);
    }

    const basename = try gpa.dupe(u8, curr.basename);
    errdefer gpa.free(basename);
    const fullpath = try gpa.dupe(u8, curr.fullpath);
    errdefer gpa.free(fullpath);
    app.sequencer_samples[idx] = .{
        .fullpath = fullpath,
        .basename = basename,
        .true_peak = curr.true_peak,
        .lufs = curr.lufs,
        .rms = curr.rms,
        .width = curr.width,
        .centroid = curr.centroid,
    };
    return .key;
}

fn handleExplore(io: Io, alloc: Allocator, app: *App, rdr: *Io.Reader) !CommandType {
    const key = try input.KeyCode.parse(rdr) orelse return .no_op;

    try app.mu.lock(io);
    defer app.mu.unlock(io);
    var cmd_type: CommandType = .key;
    switch (key) {
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
        // toggle order direction
        .o => {
            app.params.order_asc = !app.params.order_asc;
            app.page = 0;
            cmd_type = .fetch;
        },
        // toggle order mode
        .m => {
            app.params.order_by = switch (app.params.order_by) {
                .width => .centroid,
                .name => .width,
                .centroid => .name,
            };
            app.page = 0;
            cmd_type = .fetch;
        },
        // UI CHANGES
        .back_slash => {
            app.mode = .search;
        },
        .p => {
            app.mode = .push;
        },
        // reset
        .r => {
            app.search_text.clearAndFree(alloc);
            app.pitch_semitones = 0;
            app.params = .{
                .search_text = app.search_text.items,
            };
            cmd_type = .fetch;
        },
        // find similar
        .s => {
            if (app.currFile()) |curr| {
                app.search_text.clearAndFree(alloc);
                if (curr.centroid) |x| {
                    app.params.centroid.setValue(x) catch {};
                    app.params.centroid.tolerance_percent = 2;
                }
                app.params.width.setValue(curr.width) catch {};
                app.params.width.tolerance_percent = 2;
                cmd_type = .fetch;
            }
        },
        // toggle active
        .a => {
            app.active_param = switch (app.active_param) {
                .centroid => .width,
                .width => .pitch,
                .pitch => .centroid,
            };
        },
        // open selected
        .y => {
            const curr = app.currFile() orelse return .no_op;
            try curr.revealFile(io);
        },
        // cursor down
        .down => {
            if (app.next()) cmd_type = .fetch;
        },
        // cursor up
        .up => {
            if (app.prev()) cmd_type = .fetch;
        },
        // page next
        .right => {
            if (app.nextPage()) cmd_type = .fetch;
        },
        // page prev
        .left => {
            if (app.prevPage()) cmd_type = .fetch;
        },
        // play selected
        .space => {
            const midi_shift = 60 +| app.pitch_semitones;
            const midi_note: i32 = @max(0, @min(std.math.maxInt(u8), midi_shift));
            assert(midi_note >= 0);
            assert(midi_note <= std.math.maxInt(u8));

            try app.midi_ctx.queue.putOne(io, lib.midi.MidiEvent.noteOn(@intCast(midi_note)));
        },
        else => return .no_op,
    }
    return cmd_type;
}
