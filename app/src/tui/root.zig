const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("lib");

pub const App = @import("app.zig");
pub const input = @import("input.zig");

pub fn render(w: *Io.Writer, app: *const App) !void {
    _ = try w.write("\x1b[2J\x1b[H");
    _ = try w.print("order: {s}\n", .{@tagName(app.params.order_by)});
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

pub fn handleKeys(alloc: Allocator, app: *App, rdr: *Io.Reader) !void {
    const key = try input.KeyCode.parse(rdr) orelse return {};

    switch (key) {
        .o => {
            app.params.order_asc = !app.params.order_asc;
            app.page = 0;
        },
        .m => {
            app.params.order_by = switch (app.params.order_by) {
                .width => .centroid,
                .name => .width,
                .centroid => .name,
            };
            app.page = 0;
        },
        .down => app.next(),
        .up => app.prev(),
        .right => app.page +|= 1,
        .left => app.page -|= 1,
        .space => {
            const curr = app.currFile() orelse return;
            if (app.sound) |snd| {
                try lib.ma.soundStop(snd);
                lib.ma.soundClose(snd);
            }
            const cstr: [:0]u8 = try alloc.dupeSentinel(u8, curr.fullpath, 0);
            app.sound = try lib.ma.soundNew(alloc, app.engine, cstr);

            const new_amp = curr.ampToLufs(app.target_lufs);

            app.sound.?.*.set_volume(new_amp);
            try lib.ma.soundPlay(app.sound.?);
        },
        else => {},
    }
}
