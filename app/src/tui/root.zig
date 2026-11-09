const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("lib");

pub const App = @import("app.zig");
pub const input = @import("input.zig");

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
        .centroid => try w.print(dim ++ "centroid " ++ reset ++ blue ++ "{f}" ++ reset ++ "\n", .{app.params.centroid}),
        .width => try w.print(dim ++ "width " ++ reset ++ blue ++ "{f}" ++ reset ++ "\n", .{app.params.width}),
    }

    const div: [60]u8 = @splat('-');
    _ = try w.print(dim ++ "{s}" ++ reset ++ "\n", .{&div});

    _ = try w.print(dim ++ "search: " ++ reset ++ yellow ++ "{s}" ++ reset ++ "\n", .{
        app.params.search_text,
    });

    for (app.samples, 0..) |sample, idx| {
        if (idx == app.idx) {
            try w.print(green ++ "> {s}" ++ reset ++ dim ++ " (c: {d} w: {d} p: {d})" ++ reset ++ "\n", .{
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
            }
        },
        .@"2" => {
            switch (app.active_param) {
                .centroid => app.params.centroid.moveRight(5),
                .width => app.params.width.moveRight(5),
            }
        },
        .@"3" => {
            switch (app.active_param) {
                .centroid => app.params.centroid.moveTolerance(-5),
                .width => app.params.width.moveTolerance(-5),
            }
        },
        .@"4" => {
            switch (app.active_param) {
                .centroid => app.params.centroid.moveTolerance(5),
                .width => app.params.width.moveTolerance(5),
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
        // toggle active
        .a => {
            depth = .ui;
            app.active_param = switch (app.active_param) {
                .centroid => .width,
                .width => .centroid,
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
            const curr = app.currFile() orelse return depth;
            if (app.sound) |snd| {
                try lib.ma.soundStop(snd);
                lib.ma.soundClose(alloc, snd);
            }
            const cstr: [:0]u8 = try alloc.dupeSentinel(u8, curr.fullpath, 0);
            app.sound = try lib.ma.soundNew(alloc, app.engine, cstr);

            const new_amp = curr.ampToLufs(app.target_lufs);

            app.sound.?.*.set_volume(new_amp);
            try lib.ma.soundPlay(app.sound.?);
        },
        else => {},
    }
    return depth;
}
