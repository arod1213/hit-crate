const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("lib");

pub const App = @import("app.zig");
pub const input = @import("input.zig");
pub const playback = @import("playback.zig");
pub const keys = @import("keys.zig");
pub const sync = @import("sync.zig");

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
