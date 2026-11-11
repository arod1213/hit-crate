const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("lib");

pub const App = @import("app.zig");
pub const input = @import("input.zig");
pub const playback = @import("playback.zig");

pub const RenderDepth = enum { all, ui };

const reset = "\x1b[0m";
const dim = "\x1b[2m";
const blue = "\x1b[34m";
const green = "\x1b[32m";
const yellow = "\x1b[33m";

pub fn render(w: *Io.Writer, app: *const App) !void {
    _ = try w.write("\x1b[2J\x1b[H");

    _ = try w.print(dim ++ "order: " ++ reset ++ blue ++ "{s} {s}" ++ reset, .{
        @tagName(app.params.order_by),
        if (app.params.order_asc) "asc" else "desc",
    });
    _ = try w.write(dim ++ " | " ++ reset);

    switch (app.active_param) {
        .pitch => {
            try w.print(dim ++ "centroid " ++ reset ++ blue ++ "{f}" ++ reset, .{app.params.centroid});
            _ = try w.write(dim ++ " | " ++ reset);
            try w.print(dim ++ "width " ++ reset ++ blue ++ "{f}" ++ reset, .{app.params.width});
            _ = try w.write(dim ++ " | " ++ reset);
            try w.print(dim ++ "pitch " ++ reset ++ yellow ++ "{d}" ++ reset, .{app.pitch_semitones});
        },
        .centroid => {
            try w.print(dim ++ "centroid " ++ reset ++ yellow ++ "{f}" ++ reset, .{app.params.centroid});
            _ = try w.write(dim ++ " | " ++ reset);
            try w.print(dim ++ "width " ++ reset ++ blue ++ "{f}" ++ reset, .{app.params.width});
            _ = try w.write(dim ++ " | " ++ reset);
            try w.print(dim ++ "pitch " ++ reset ++ blue ++ "{d}" ++ reset, .{app.pitch_semitones});
        },
        .width => {
            try w.print(dim ++ "centroid " ++ reset ++ blue ++ "{f}" ++ reset, .{app.params.centroid});
            _ = try w.write(dim ++ " | " ++ reset);
            try w.print(dim ++ "width " ++ reset ++ yellow ++ "{f}" ++ reset, .{app.params.width});
            _ = try w.write(dim ++ " | " ++ reset);
            try w.print(dim ++ "pitch " ++ reset ++ blue ++ "{d}" ++ reset, .{app.pitch_semitones});
        },
    }
    _ = try w.write("\n");

    const div: [60]u8 = @splat('-');
    _ = try w.print(dim ++ "{s}" ++ reset ++ "\n", .{&div});

    _ = try w.print(dim ++ "search: " ++ reset ++ yellow ++ "{s}" ++ reset ++ "\n", .{
        app.params.search_text,
    });

    for (app.samples, 0..) |sample, idx| {
        if (idx == app.idx) {
            try w.print(green ++ "> {s}" ++ reset ++ dim ++ " (c: {d:>5.1} w: {d:>3.1} p: {d:>3.2})" ++ reset ++ "\n", .{
                sample.basename,
                sample.centroid orelse 0,
                sample.width,
                sample.true_peak orelse 0,
            });
        } else {
            try w.print("  {s}\n", .{sample.basename});
        }
    }
    try w.flush();
}

pub fn handleKeys(io: Io, alloc: Allocator, app: *App, rdr: *Io.Reader) !RenderDepth {
    switch (app.mode) {
        .explore => return try handleExplore(io, alloc, app, rdr),
        .search => {
            try handleSearch(alloc, app, rdr);
            return .all;
        },
    }
}

pub fn handleSearch(alloc: Allocator, app: *App, rdr: *Io.Reader) !void {
    const b = try rdr.takeByte();
    switch (b) {
        '\n', '\r', 0x1B => app.mode = .explore,
        0x7F, 0x08 => _ = {
            _ = app.search_text.pop();
            app.page = 0;
            app.idx = 0;
        },
        else => {
            try app.search_text.append(alloc, b);
            app.page = 0;
            app.idx = 0;
        },
    }
}

pub fn handleExplore(io: Io, alloc: Allocator, app: *App, rdr: *Io.Reader) !RenderDepth {
    const key = try input.KeyCode.parse(rdr) orelse return .ui;

    var depth: RenderDepth = .all;
    switch (key) {
        .@"1" => {
            switch (app.active_param) {
                .centroid => app.params.centroid.moveLeft(5),
                .width => app.params.width.moveLeft(5),
                .pitch => app.setPitch(app.pitch_semitones - 1),
            }
        },
        .@"2" => {
            switch (app.active_param) {
                .centroid => app.params.centroid.moveRight(5),
                .width => app.params.width.moveRight(5),
                .pitch => app.setPitch(app.pitch_semitones + 1),
            }
        },
        .@"3" => {
            switch (app.active_param) {
                .centroid => app.params.centroid.moveTolerance(-5),
                .width => app.params.width.moveTolerance(-5),
                .pitch => {},
            }
        },
        .@"4" => {
            switch (app.active_param) {
                .centroid => app.params.centroid.moveTolerance(5),
                .width => app.params.width.moveTolerance(5),
                .pitch => {},
            }
        },
        // toggle order direction
        .o => {
            app.params.order_asc = !app.params.order_asc;
            app.page = 0;
        },
        // toggle order mode
        .m => {
            app.params.order_by = switch (app.params.order_by) {
                .width => .centroid,
                .name => .width,
                .centroid => .name,
            };
            app.page = 0;
        },
        // UI CHANGES
        .back_slash => {
            depth = .ui;
            app.mode = .search;
        },
        // reset
        .r => {
            app.search_text.clearAndFree(alloc);
            app.params = .{
                .search_text = app.search_text.items,
            };
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
            }
        },
        // toggle active
        .a => {
            depth = .ui;
            app.active_param = switch (app.active_param) {
                .centroid => .width,
                .width => .pitch,
                .pitch => .centroid,
            };
        },
        // open selected
        .y => {
            depth = .ui;
            const curr = app.currFile() orelse return depth;
            try curr.revealFile(io);
        },
        // cursor down
        .down => {
            if (!app.next()) depth = .ui;
        },
        // cursor up
        .up => {
            if (!app.prev()) depth = .ui;
        },
        // page next
        .right => {
            if (!app.nextPage()) depth = .ui;
        },
        // page prev
        .left => {
            if (!app.prevPage()) depth = .ui;
        },
        // play selected
        .space => {
            depth = .ui;
            try app.publishSelection(alloc);
            try app.midi_ctx.queue.putOne(io, lib.midi.MidiEvent.noteOn(60 +| app.pitch_semitones));
        },
        else => {},
    }
    return depth;
}
