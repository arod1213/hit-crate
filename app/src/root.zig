//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const miniaudio = @import("miniaudio");

pub const decode = @import("audio/decode.zig");
pub const audio = @import("audio/root.zig");
pub const scanner = @import("scanner.zig");
pub const ma = @import("sys/miniaudio.zig");
pub const db = @import("sys/sqlite.zig");

pub const SampleEntry = struct {
    fullpath: []const u8,
    basename: []const u8,
    rms: f32,
    lufs: ?f32,
    width: f32,
    true_peak: ?f32,
    centroid: ?f32,

    const Self = @This();
    pub fn ampToLufs(self: Self, target_lufs: f32) f32 {
        const rms_amp =
            audio.ampToTarget(f32, self.rms, target_lufs);
        const lufs_amp =
            if (self.lufs) |lufs|
                audio.ampToTarget(f32, lufs, target_lufs)
            else
                1;
        const tp_amp =
            if (self.true_peak) |tp|
                audio.ampToTarget(f32, tp, target_lufs)
            else
                1;
        const avg = (rms_amp + lufs_amp + tp_amp) / 3;
        return @min(2, avg);
    }

    pub fn revealFile(self: Self, io: Io) !void {
        _ = try std.process.spawn(io, .{
            .argv = &[_][]const u8{
                "open", "-R", self.fullpath,
            },
        });
    }
};

// TODO: make this do exponential scaling so button press moves 5% in either direction (nice UX for TUI)
// fn Slider(comptime exp_scale: f32, lower: f32, upper: f32) type {
//     assert(lower <= upper);
//     return struct {
//         curr_percent: f32 = 0.0,
//         value: f32 = lower,
//         diff: f32 = upper - lower,
//
//         const SliderSelf = @This();
//         pub fn setPos(self: SliderSelf, percent: f32) void {
//             assert(percent >= 0.0);
//             assert(percent <= 100.0);
//
//             const scale_percent = percent * exp_scale / 100;
//             assert(scale_percent >= 0);
//             assert(scale_percent <= 1.0);
//             self.value = lower + (scale_percent * self.diff);
//             self.curr_percent = percent;
//         }
//     };
// }
//
// const Params = struct {
//     width: Slider(1, 0, 200) = .{},
//     centroid: Slider(0.2, 0, 9_000) = .{},
// };

const Slider = struct {
    floor: f32, // MIN value
    ceiling: f32, // MAX value

    exp_scale: f32, // 1 = no scaling, 0.9 slower ramping
    tolerance_percent: f32, // 0.0 to 100.0

    slider_pos_percent: f32, // 0.0 to 100.0

    const Self = @This();
    pub fn value(self: Self) f32 {
        const diff = self.ceiling - self.floor;
        const scaled_percent = std.math.pow(f32, self.slider_pos_percent / 100, self.exp_scale);
        const diff_change = scaled_percent * diff;
        return self.floor + diff_change;
    }

    pub fn bound(self: Self, lower: bool) f32 {
        const diff = self.ceiling - self.floor;
        const percentile = self.slider_pos_percent + if (lower)
            -self.tolerance_percent
        else
            self.tolerance_percent;
        const percentile_bounded: f32 = @max(0.0, @min(100.0, percentile)) / 100.0;
        const scaled_percent = std.math.pow(f32, percentile_bounded, self.exp_scale);

        // std.log.info("pos {d} tol {d} pct {d} bound {d} scaled {d}", .{
        //     self.slider_pos_percent,
        //     self.tolerance_percent,
        //     percentile,
        //     percentile_bounded,
        //     scaled_percent,
        // });
        const diff_change = scaled_percent * diff;
        return self.floor + diff_change;
    }

    pub fn moveTolerance(self: *Self, by: f32) void {
        const val = self.tolerance_percent + by;
        self.tolerance_percent = @max(0.0, @min(100.0, val));
    }

    pub fn moveRight(self: *Self, percent: f32) void {
        const val = self.slider_pos_percent + percent;
        self.slider_pos_percent = @min(100.0, val);
    }

    pub fn moveLeft(self: *Self, percent: f32) void {
        const val = self.slider_pos_percent - percent;
        self.slider_pos_percent = @max(0, val);
    }

    pub fn format(self: Self, w: *Io.Writer) !void {
        _ = try w.print("{d} - {d}", .{
            self.bound(true),
            self.bound(false),
        });
    }
};

pub const OrderParams = enum {
    centroid,
    width,
    name,
    const Self = @This();
    pub fn asClause(self: Self, order_asc: bool) []const u8 {
        return switch (self) {
            inline else => |tag| if (order_asc)
                "ORDER BY s." ++ @tagName(tag) ++ " ASC"
            else
                "ORDER BY s." ++ @tagName(tag) ++ " DESC",
        };
    }
};
pub const SearchParams = struct {
    search_text: []const u8,
    width: Slider = .{
        .floor = 0,
        .ceiling = 200,
        .slider_pos_percent = 50,
        .exp_scale = 1,
        .tolerance_percent = 50,
    },
    centroid: Slider = .{
        .floor = 0,
        .ceiling = 9_000,
        .slider_pos_percent = 50,
        .exp_scale = 1,
        .tolerance_percent = 50,
    },
    order_by: OrderParams = .width,
    order_asc: bool = true,
};

pub fn querySamples(gpa: Allocator, conn: db.Connection, params: SearchParams, limit: usize, page: usize) ![]SampleEntry {
    const sql =
        if (params.search_text.len > 0)
            try std.fmt.allocPrintSentinel(gpa,
                \\ SELECT s.path, s.name, s.width, s.true_peak, s.rms, s.centroid
                \\ FROM samples s
                \\ JOIN samples_fts f on f.rowid = s.rowid
                \\ WHERE f.name MATCH ?1 || '*'
                \\ AND s.width BETWEEN ?2 and ?3
                \\ AND s.centroid BETWEEN ?4 and ?5
                \\ {s}
                \\ LIMIT ?6 OFFSET ?7
            , .{params.order_by.asClause(params.order_asc)}, 0)
        else
            try std.fmt.allocPrintSentinel(gpa,
                \\ SELECT s.path, s.name, s.width, s.true_peak, s.rms, s.centroid
                \\ FROM samples s
                \\ WHERE ?1 IS NULL
                \\ AND s.width BETWEEN ?2 and ?3
                \\ AND s.centroid BETWEEN ?4 and ?5
                \\ {s}
                \\ LIMIT ?6 OFFSET ?7
            , .{params.order_by.asClause(params.order_asc)}, 0);
    defer gpa.free(sql);

    const stmt = try db.prepare(conn, sql);
    defer db.stmtClose(stmt) catch {};
    try db.stmtBindMany(stmt, .{
        if (params.search_text.len == 0) null else params.search_text,
        params.width.bound(true),
        params.width.bound(false),
        params.centroid.bound(true),
        params.centroid.bound(false),
        limit,
        page * limit,
    });

    var sample_list = try std.ArrayList(SampleEntry).initCapacity(gpa, 50);
    defer sample_list.deinit(gpa);

    while (true) {
        const res = try db.stmtStep(stmt);
        if (res != .Row) break;

        var sample = std.mem.zeroes(SampleEntry);
        try db.stmtReadMany(gpa, stmt, .{
            &sample.fullpath,
            &sample.basename,
            &sample.width,
            &sample.true_peak,
            &sample.rms,
            &sample.centroid,
        });
        try sample_list.append(gpa, sample);
    }
    return try sample_list.toOwnedSlice(gpa);
}
