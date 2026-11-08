//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const decode = @import("audio/decode.zig");
const audio = @import("audio/root.zig");
const ma = @import("sys/miniaudio.zig");
pub const db = @import("sys/sqlite.zig");

pub fn saveDir(io: Io, absoluteDir: []const u8, conn: db.Connection) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dir = try Io.Dir.openDirAbsolute(io, absoluteDir, .{ .iterate = true });
    defer dir.close(io);

    var iter = try dir.walk(std.heap.smp_allocator);
    defer iter.deinit();

    var buffer: [5_000]audio.Sample = undefined;
    var queue = InsertQueue.init(&buffer);

    var fut = io.async(consumerLoop, .{ io, conn, &queue });
    defer fut.cancel(io) catch {};

    var group = Io.Group.init;
    defer group.cancel(io);

    while (try iter.next(io)) |entry| {
        switch (entry.kind) {
            .file => {},
            else => continue,
        }
        const ext = audio.AudioExt.fromPath(entry.basename) orelse continue;

        const fullpath = try std.fs.path.join(alloc, &[_][]const u8{
            absoluteDir,
            entry.path,
        });
        group.async(io, producerLoop, .{ io, &queue, fullpath, ext });
    }

    try group.await(io);
    queue.close(io);
    _ = try fut.await(io);
}

const InsertQueue = Io.Queue(audio.Sample);

fn consumerLoop(io: Io, conn: db.Connection, consumer: *InsertQueue) !void {
    try db.exec(conn, "PRAGMA journal_mode=WAL");
    try db.txStart(conn);
    defer db.txRollback(conn);

    const sql = "INSERT INTO samples (path, name, ext, duration_ms, lufs, true_peak, rms, width, centroid) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT DO NOTHING";
    const BATCH_SIZE = 200_000;
    const stmt = try db.prepare(conn, sql);
    defer db.stmtClose(stmt) catch {};

    var inserted: usize = 0;
    while (true) {
        const sample = consumer.getOne(io) catch |e| {
            switch (e) {
                error.Closed => break,
                else => return e,
            }
        };
        db.stmtBindMany(stmt, .{
            sample.fullpath,
            sample.basename,
            @tagName(sample.ext),
            sample.duration_ms,
            sample.lufs,
            sample.true_peak,
            sample.rms,
            sample.width,
            sample.centroid,
        }) catch |e| {
            std.log.err("failed to bind: {}", .{e});
            continue;
        };
        defer db.stmtReset(stmt) catch {};
        _ = db.stmtStep(stmt) catch {
            std.log.err("failed to exec", .{});
            continue;
        };
        inserted += 1;

        if (inserted != 0 and inserted % BATCH_SIZE == 0) {
            try db.txCommit(conn);
            try db.txStart(conn);
        }
    }
    try db.txCommit(conn);
    std.log.info("finished scan: inserted {d}", .{inserted});
}

fn producerLoop(io: Io, producer: *InsertQueue, fullpath: []const u8, ext: audio.AudioExt) Io.Cancelable!void {
    producerInner(io, producer, fullpath, ext) catch |e| {
        switch (e) {
            Io.Cancelable.Canceled => return Io.Cancelable.Canceled,
            else => {
                std.log.err("err reading file {}", .{e});
                return {};
            },
        }
    };
    std.log.info("queued file", .{});
}

fn producerInner(io: Io, producer: *InsertQueue, fullpath: []const u8, ext: audio.AudioExt) !void {
    const duration_ms, const sample_rate, const channels = switch (ext) {
        .wav, .WAV => blk: {
            const wav = decode.Wave.fromFilePath(io, fullpath) catch |e| {
                std.log.err("failed to open wav: {}", .{e});
                return e;
            };
            break :blk .{ wav.durationMs(), wav.fmt.sample_rate, wav.fmt.num_channels };
        },
        // else => .{ 0, 0, 0 },
    };

    const MAX_LEN_MS = 9_000;
    const READ_LEN_MS = 5_000;
    if (duration_ms > MAX_LEN_MS) return error.TooLong;
    if (sample_rate == 0) return error.NoSampleRate;

    const alloc = std.heap.page_allocator;
    const cstr = try alloc.dupeSentinel(u8, fullpath, 0);
    defer alloc.free(cstr);

    var decoder = try ma.Decoder.init(alloc, cstr, channels, sample_rate);
    defer decoder.deinit(alloc);
    const meta = try audio.AudioMeta.fromDecoder(alloc, &decoder, READ_LEN_MS);

    const data = audio.Sample{
        .true_peak = meta.true_peak,
        .sample_rate = sample_rate,
        .channels = channels,
        .fullpath = fullpath,
        .basename = std.fs.path.basename(fullpath),
        .ext = ext,
        .duration_ms = duration_ms,
        .rms = meta.rms,
        .lufs = meta.lufs,
        .width = meta.width,
        .centroid = meta.centroid,
    };
    try producer.putOne(io, data);
}
