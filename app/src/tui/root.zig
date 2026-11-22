const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("lib");

pub const App = @import("app.zig");
pub const input = @import("input.zig");
pub const keys = @import("keys.zig");
pub const kits = @import("kits.zig");
pub const playback = @import("playback.zig");
pub const sync = @import("sync.zig");

pub const RenderDepth = enum { all, ui };

const reset = "\x1b[0m";
const dim = "\x1b[2m";
const blue = "\x1b[34m";
const green = "\x1b[32m";
const yellow = "\x1b[33m";

pub fn render(io: Io, w: *Io.Writer, app: *App) !void {
    switch (app.mode) {
        .track => |idx| try renderTrack(io, w, app, idx),
        else => try renderSearch(io, w, app),
    }
}

fn renderTrack(io: Io, w: *Io.Writer, app: *App, idx: usize) !void {
    try app.sample_slots.mu.lock(io);
    defer app.sample_slots.mu.unlock(io);
    const curr_slot = &app.sample_slots.slots[idx];

    const path, const gain, const pitch, const offset_ms = if (curr_slot.*) |s| .{
        s.fullpath,
        s.gain_db,
        s.pitch_offset,
        s.start_offset_ms,
    } else .{
        "no sample...",
        0,
        0,
        0.0,
    };
    _ = try w.write("\x1b[2J\x1b[H");

    _ = try w.print("slot {d}/{d}", .{ idx + 1, app.sample_slots.slots.len });
    _ = try w.write(dim ++ " | " ++ reset);
    _ = try w.print("pitch {d:3.1}", .{pitch});
    _ = try w.write(dim ++ " | " ++ reset);
    _ = try w.print("gain {d:3.1}", .{gain});
    _ = try w.write(dim ++ " | " ++ reset);
    _ = try w.print("offset (ms) {d:2.1}", .{offset_ms});
    _ = try w.write("\n");

    const div: [60]u8 = @splat('-');
    _ = try w.print(dim ++ "{s}" ++ reset ++ "\n", .{&div});

    _ = try w.print("sample: {s}", .{std.fs.path.basename(path)});
    _ = try w.write("\n");

    try w.flush();
}

fn renderSearch(io: Io, w: *Io.Writer, app: *App) !void {
    _ = try w.write("\x1b[2J\x1b[H");

    // render params + sample list
    {
        try app.mu.lock(io);
        defer app.mu.unlock(io);

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
    }

    {
        try app.sample_slots.mu.lock(io);
        defer app.sample_slots.mu.unlock(io);
        for (app.sample_slots.slots, 0..) |seq, idx| {
            // skip last slot for selected track
            if (idx == app.sample_slots.slots.len - 1) break;

            if (seq) |_| {
                try w.print("{d}: ^^^", .{idx + 1});
            } else {
                try w.print("{d}: nil", .{idx + 1});
            }
            _ = try w.write(" | ");
        }
    }

    try w.flush();
}
