const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("lib");

pub const App = @import("app.zig");
pub const input = @import("input.zig");

pub const RenderDepth = enum { all, ui };

pub fn render(w: *Io.Writer, app: *const App) !void {
    _ = try w.write("\x1b[2J\x1b[H");

    _ = try w.print("order asc: {s} {}\n", .{
        @tagName(app.params.order_by),
        app.params.order_asc,
    });

    _ = try w.print("param {s} \n", .{
        @tagName(app.active_param),
    });

    _ = try w.print("centroid {f} | width {f} \n", .{
        app.params.centroid,
        app.params.width,
    });

    _ = try w.print("search: {s}\n", .{
        app.params.search_text,
    });

    for (app.samples, 0..) |sample, idx| {
        if (idx == app.idx) {
            try w.print(">: {s} (c: {d} w: {d} p: {d}\n", .{
                sample.basename,
                sample.centroid orelse 0,
                sample.width,
                sample.true_peak orelse 0,
            });
        } else {
            try w.print(" : {s}\n", .{sample.basename});
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

    var depth: RenderDepth = .ui;
    switch (key) {
        .@"1" => {
            depth = .all;
            switch (app.active_param) {
                .centroid => app.params.centroid.moveLeft(5),
                .width => app.params.width.moveLeft(5),
            }
        },
        .@"2" => {
            depth = .all;
            switch (app.active_param) {
                .centroid => app.params.centroid.moveRight(5),
                .width => app.params.width.moveRight(5),
            }
        },
        .@"3" => {
            depth = .all;
            switch (app.active_param) {
                .centroid => app.params.centroid.moveTolerance(-5),
                .width => app.params.width.moveTolerance(-5),
            }
        },
        .@"4" => {
            depth = .all;
            switch (app.active_param) {
                .centroid => app.params.centroid.moveTolerance(5),
                .width => app.params.width.moveTolerance(5),
            }
        },
        .b => {
            app.active_param = switch (app.active_param) {
                .centroid => .width,
                .width => .centroid,
            };
        },
        .y => {
            const curr = app.currFile() orelse return depth;
            try curr.revealFile(io);
        },
        .back_slash => app.mode = .search,
        .o => {
            depth = .all;
            app.params.order_asc = !app.params.order_asc;
            app.page = 0;
        },
        .m => {
            depth = .all;
            app.params.order_by = switch (app.params.order_by) {
                .width => .centroid,
                .name => .width,
                .centroid => .name,
            };
            app.page = 0;
        },
        .down => {
            if (app.next()) depth = .all;
        },
        .up => {
            if (app.prev()) depth = .all;
        },
        .right => {
            depth = .all;
            if (app.nextPage()) depth = .all;
        },
        .left => {
            if (app.prevPage()) depth = .all;
        },
        .space => {
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
