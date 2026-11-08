//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

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
};

pub fn Range(comptime T: type) type {
    return struct {
        target: T,
        tolerance_upper: T,
        tolerance_lower: T,
    };
}

pub const OrderParams = enum {
    centroid,
    width,
    name,
    const Self = @This();
    pub fn asClause(self: Self, order_asc: bool) []const u8 {
        return switch (self) {
            inline else => |tag| if (order_asc)
                "ORDER BY " ++ @tagName(tag) ++ " ASC"
            else
                "ORDER BY " ++ @tagName(tag) ++ " DESC",
        };
    }
};
pub const SearchParams = struct {
    search_name: []const u8,
    width: Range(f32) = .{ .target = 100, .tolerance_lower = 100, .tolerance_upper = 100 },
    centroid: Range(f32) = .{ .target = 50, .tolerance_lower = 0, .tolerance_upper = 5_000 },
    order_by: OrderParams = .width,
    order_asc: bool = true,
};

pub fn querySamples(gpa: Allocator, conn: db.Connection, params: SearchParams, limit: usize, page: usize) ![]SampleEntry {
    const name_clause = if (params.search_name.len > 0)
        "lower(name) LIKE lower(?1) || '%'"
    else
        "?1 is null";

    const sql = try std.fmt.allocPrintSentinel(gpa,
        \\ SELECT path, name, width, true_peak, rms, centroid
        \\ FROM samples 
        \\ WHERE {s}
        \\ AND width BETWEEN (?2 - ?3) and (?2 + ?4)
        \\ AND centroid BETWEEN (?5 - ?6) and (?5 + ?7)
        \\ {s}
        \\ LIMIT ?8 OFFSET ?9
    , .{ name_clause, params.order_by.asClause(params.order_asc) }, 0);
    defer gpa.free(sql);

    const stmt = try db.prepare(conn, sql);
    defer db.stmtClose(stmt) catch {};
    try db.stmtBindMany(stmt, .{
        if (params.search_name.len == 0) null else params.search_name,
        params.width.target,
        params.width.tolerance_lower,
        params.width.tolerance_upper,
        params.centroid.target,
        params.centroid.tolerance_lower,
        params.centroid.tolerance_upper,
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
