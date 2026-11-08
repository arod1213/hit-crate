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
    width: Range(f32) = .{ .target = 100, .tolerance_lower = 100, .tolerance_upper = 100 },
    order_by: OrderParams = .width,
    order_asc: bool = true,
};

pub fn audioFilesDb(gpa: Allocator, conn: db.Connection, params: SearchParams, limit: usize, page: usize) ![]SampleEntry {
    const sql = try std.fmt.allocPrintSentinel(gpa,
        \\ SELECT path, name, width, true_peak, rms, centroid
        \\ FROM samples 
        \\ WHERE lufs is not null 
        \\ AND width BETWEEN (?1 - ?2) and (?1 + ?3)
        \\ AND centroid > 0
        \\ {s}
        \\ LIMIT ?4 OFFSET ?5
    , .{params.order_by.asClause(params.order_asc)}, 0);
    defer gpa.free(sql);

    const stmt = try db.prepare(conn, sql);
    defer db.stmtClose(stmt) catch {};
    try db.stmtBindMany(stmt, .{
        params.width.target,
        params.width.tolerance_lower,
        params.width.tolerance_upper,
        limit,
        page * limit,
    });

    var list = try std.ArrayList(SampleEntry).initCapacity(gpa, 50);
    defer list.deinit(gpa);

    while (true) {
        const res = try db.stmtStep(stmt);
        if (res != .Row) break;

        var e = std.mem.zeroes(SampleEntry);
        try db.stmtReadMany(gpa, stmt, .{
            &e.fullpath,
            &e.basename,
            &e.width,
            &e.true_peak,
            &e.rms,
            &e.centroid,
        });
        try list.append(gpa, e);
    }
    return try list.toOwnedSlice(gpa);
}

pub fn audioFiles(alloc: Allocator, io: Io, path: []const u8) ![]SampleEntry {
    const cwd = Io.Dir.cwd();
    var dir = try Io.Dir.openDir(cwd, io, path, .{ .iterate = true });
    defer dir.close(io);

    var list = try std.ArrayList(SampleEntry).initCapacity(alloc, 500);
    defer list.deinit(alloc);

    var iter = try dir.walk(std.heap.page_allocator);
    defer iter.deinit();

    while (try iter.next(io)) |entry| {
        switch (entry.kind) {
            .file => {},
            else => continue,
        }
        if (audio.AudioExt.fromPath(entry.basename) == null) continue;
        const fullpath = try std.fs.path.join(alloc, &[_][]const u8{ path, entry.path });
        const base = try alloc.dupe(u8, entry.basename);
        const e = SampleEntry{
            .fullpath = fullpath,
            .basename = base,
            .lufs = null,
        };
        try list.append(alloc, e);
    }

    return try list.toOwnedSlice(alloc);
}

test {
    std.testing.refAllDecls(@This());
}
