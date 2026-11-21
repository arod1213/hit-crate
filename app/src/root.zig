//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const miniaudio = @import("miniaudio");

pub const decode = @import("audio/decode.zig");
pub const audio = @import("audio/root.zig");
pub const scanner = @import("scanner.zig");
pub const midi = @import("sys/coremidi.zig");
pub const ma = @import("sys/miniaudio.zig");
pub const db = @import("sys/sqlite.zig");

test "submods" {
    std.testing.refAllDecls(@This());
}
pub fn revealFile(io: Io, fullpath: []const u8) !void {
    _ = try std.process.spawn(io, .{
        .argv = &[_][]const u8{
            "open", "-R", fullpath,
        },
    });
}

pub const SampleEntry = struct {
    fullpath: []const u8,
    basename: []const u8,
    rms: f32,
    lufs: ?f32,
    width: f32,
    true_peak: ?f32,
    centroid: ?f32,
};

pub const Slider = struct {
    floor: f32, // MIN value
    ceiling: f32, // MAX value

    exp_scale: f32, // 1 = no scaling, 0.9 slower ramping
    tolerance_percent: f32, // 0.0 to MAX_TOLERANCE

    slider_pos_percent: f32, // 0.0 to MAX_TOLERANCE
    const MAX_TOLERANCE = 50.0; // 50 in either direction

    const Self = @This();
    pub fn value(self: Self) f32 {
        const range = self.ceiling - self.floor;
        const scaled_percent = std.math.pow(f32, self.slider_pos_percent / 100, self.exp_scale);
        const diff_change = scaled_percent * range;
        return self.floor + diff_change;
    }

    pub fn setValue(self: *Self, x: f32) !void {
        if (x < self.floor or x > self.ceiling) return error.OutOfBounds;
        const range = self.ceiling - self.floor;
        assert(range > 0);
        const move = x - self.floor;
        const res = std.math.pow(f32, move / range, 1.0 / self.exp_scale) * 100.0;

        self.slider_pos_percent = @min(100.0, @max(0, res));
    }

    pub fn bound(self: Self, lower: bool) f32 {
        const range = self.ceiling - self.floor;
        const percentile = self.slider_pos_percent + if (lower)
            -self.tolerance_percent
        else
            self.tolerance_percent;
        const percentile_bounded: f32 = @max(0.0, @min(100.0, percentile)) / 100.0;
        const scaled_percent = std.math.pow(f32, percentile_bounded, self.exp_scale);

        const diff_change = scaled_percent * range;
        return self.floor + diff_change;
    }

    pub fn moveTolerance(self: *Self, by: f32) void {
        const val = self.tolerance_percent + by;
        if (val > MAX_TOLERANCE) {
            self.moveRight(5);
        } else if (val < 0.0) {
            self.moveLeft(5);
        }
        self.tolerance_percent = @max(0.0, @min(MAX_TOLERANCE, val));
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
        _ = try w.print("{d:.0} - {d:.0}", .{
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
    /// unsupported for batch queries at the moment
    duration_ms_max: u32 = 5_000,
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
        if (params.search_text.len > 2)
            try std.fmt.allocPrintSentinel(gpa,
                \\ SELECT s.path, s.name, s.width, s.true_peak, s.rms, s.centroid
                \\ FROM samples s
                \\ JOIN samples_fts f on f.rowid = s.rowid
                \\ WHERE f.name MATCH '"' || replace(?1, '"', '""') || '"'
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

/// get one sample
pub fn querySample(gpa: Allocator, conn: db.Connection, params: SearchParams) !?SampleEntry {
    const duration_clause = "duration_ms <= ?6";
    const sql =
        if (params.search_text.len > 2)
            try std.fmt.allocPrintSentinel(gpa,
                \\ SELECT s.path, s.name, s.width, s.true_peak, s.rms, s.centroid
                \\ FROM samples s
                \\ JOIN samples_fts f on f.rowid = s.rowid
                \\ WHERE f.name MATCH '"' || replace(?1, '"', '""') || '"'
                \\ AND s.width BETWEEN ?2 and ?3
                \\ AND s.centroid BETWEEN ?4 and ?5
                \\ AND {s}
                \\ LIMIT 1
            , .{duration_clause}, 0)
        else
            try std.fmt.allocPrintSentinel(gpa,
                \\ SELECT s.path, s.name, s.width, s.true_peak, s.rms, s.centroid
                \\ FROM samples s
                \\ WHERE ?1 IS NULL
                \\ AND s.width BETWEEN ?2 and ?3
                \\ AND s.centroid BETWEEN ?4 and ?5
                \\ AND {s}
                \\ LIMIT 1
            , .{duration_clause}, 0);
    defer gpa.free(sql);

    const stmt = try db.prepare(conn, sql);
    defer db.stmtClose(stmt) catch {};
    try db.stmtBindMany(stmt, .{
        if (params.search_text.len == 0) null else params.search_text,
        params.width.bound(true),
        params.width.bound(false),
        params.centroid.bound(true),
        params.centroid.bound(false),
        params.duration_ms_max,
    });

    const res = try db.stmtStep(stmt);
    if (res != .Row) return null;

    var sample = std.mem.zeroes(SampleEntry);
    try db.stmtReadMany(gpa, stmt, .{
        &sample.fullpath,
        &sample.basename,
        &sample.width,
        &sample.true_peak,
        &sample.rms,
        &sample.centroid,
    });
    return sample;
}

test "set value" {
    const t = struct {
        pub fn fuzzTest(_: void, smith: *std.testing.Smith) !void {
            const FLOOR = 0;
            const CEIL = 10_000;
            var slider: Slider = .{
                .ceiling = CEIL,
                .floor = FLOOR,
                .exp_scale = 1,
                .tolerance_percent = 2,
                .slider_pos_percent = 0,
            };
            const value = smith.valueRangeAtMost(u16, FLOOR, CEIL);
            const float_value: f32 = @floatFromInt(value);
            try slider.setValue(float_value);
            const lower = slider.bound(true);
            const upper = slider.bound(false);
            try std.testing.expect(float_value >= lower);
            try std.testing.expect(float_value <= upper);
        }
    };
    try std.testing.fuzz({}, t.fuzzTest, .{});
}
