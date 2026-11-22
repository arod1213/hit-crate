//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;

const decode = @import("audio/decode.zig");
const audio = @import("audio/root.zig");
const ma = @import("sys/miniaudio.zig");
pub const db = @import("sys/sqlite.zig");

pub fn saveDir(io: Io, gpa: Allocator, absolute_dir: []const u8, conn: db.Connection) !void {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var dir = try Io.Dir.openDirAbsolute(io, absolute_dir, .{ .iterate = true });
    defer dir.close(io);

    var iter = try dir.walk(gpa);
    defer iter.deinit();

    var buffer: [5_000]audio.Sample = undefined;
    var queue = InsertQueue.init(&buffer);

    var fut = try io.concurrent(consumerLoop, .{ io, gpa, conn, &queue });
    defer fut.cancel(io) catch {};

    var group = Io.Group.init;
    defer group.cancel(io);

    while (try iter.next(io)) |entry| {
        switch (entry.kind) {
            .file => {},
            else => continue,
        }
        const ext = audio.AudioExt.fromPath(entry.basename) orelse continue;

        const path = try arena_alloc.dupe(u8, entry.path);
        const data: ProducerData = .{
            .absolute_dir = absolute_dir,
            .ext = ext,
            .rel_path = path,
        };

        group.async(io, producerLoop, .{ io, gpa, &queue, data });
    }

    try group.await(io);
    queue.close(io);
    _ = try fut.await(io);
}

const InsertQueue = Io.Queue(audio.Sample);

const sample_insert_sql = @embedFile("./sql/sample_insert.sql");
fn consumerLoop(io: Io, gpa: Allocator, conn: db.Connection, consumer: *InsertQueue) !void {
    try db.exec(conn, "PRAGMA journal_mode=WAL");
    try db.txStart(conn);
    defer db.txRollback(conn);

    const BATCH_SIZE = 10_000;
    const stmt = try db.prepare(conn, sample_insert_sql);
    defer db.stmtClose(stmt) catch {};

    var inserted: usize = 0;
    while (true) {
        const sample = consumer.getOne(io) catch |e| {
            switch (e) {
                error.Closed => break,
                else => return e,
            }
        };
        defer gpa.free(sample.fullpath);

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

fn producerLoop(io: Io, gpa: Allocator, producer: *InsertQueue, data: ProducerData) Io.Cancelable!void {
    producerInner(io, gpa, producer, data) catch |e| {
        switch (e) {
            Io.Cancelable.Canceled => return Io.Cancelable.Canceled,
            else => {
                std.log.debug("err reading file {}", .{e});
                return {};
            },
        }
    };
    std.log.info("queued file", .{});
}

const ProducerData = struct {
    absolute_dir: []const u8,
    rel_path: []const u8,
    ext: audio.AudioExt,
};

fn producerInner(io: Io, gpa: Allocator, producer: *InsertQueue, data: ProducerData) !void {
    const fullpath = try std.fs.path.join(gpa, &[_][]const u8{
        data.absolute_dir,
        data.rel_path,
    });
    errdefer gpa.free(fullpath);

    const duration_ms, const sample_rate, const channels = switch (data.ext) {
        .wav, .WAV => blk: {
            const wav = decode.Wave.fromFilePath(io, fullpath) catch |e| {
                std.log.debug("failed to open wav: {} @ {s}", .{ e, fullpath });
                return e;
            };
            break :blk .{ wav.durationMs(), wav.fmt.sample_rate, wav.fmt.num_channels };
        },
    };

    const MAX_LEN_MS = 9_000;
    const READ_LEN_MS = 5_000;
    if (duration_ms > MAX_LEN_MS) return error.TooLong;
    if (sample_rate == 0) return error.NoSampleRate;

    const cstr = try gpa.dupeSentinel(u8, fullpath, 0);
    defer gpa.free(cstr);

    var decoder = try ma.Decoder.init(gpa, cstr, channels, sample_rate);
    defer decoder.deinit(gpa);
    const meta = try audio.AudioMeta.fromDecoder(gpa, &decoder, READ_LEN_MS);

    const sample = audio.Sample{
        .true_peak = meta.true_peak,
        .sample_rate = sample_rate,
        .channels = channels,
        .fullpath = fullpath,
        .basename = std.fs.path.basename(fullpath),
        .ext = data.ext,
        .duration_ms = duration_ms,
        .rms = meta.rms,
        .lufs = meta.lufs,
        .width = meta.width,
        .centroid = meta.centroid,
    };
    try producer.putOne(io, sample);
}

///////////////////////////////////////////////
// TESTS
///////////////////////////////////////////////

test "test leak" {
    const alloc = std.testing.allocator;
    var thread = std.Io.Threaded.init(alloc, .{});
    defer thread.deinit();
    const io = thread.io();

    var buffer: [5_000]audio.Sample = undefined;
    var queue = InsertQueue.init(&buffer);

    const conn = try db.connectMemory();
    try db.migrate(conn);

    var fut = io.async(consumerLoop, .{ io, alloc, conn, &queue });
    defer fut.cancel(io) catch {};

    var group = Io.Group.init;
    defer group.cancel(io);

    for (0..1_000) |_| {
        const data: ProducerData = .{
            // using relative cause FUCK IT
            .absolute_dir = "./src/test-fixtures",
            .ext = .wav,
            .rel_path = "hat.wav",
        };
        group.async(io, producerLoop, .{ io, alloc, &queue, data });
    }

    try group.await(io);
    queue.close(io);
    _ = try fut.await(io);
}

test "test dir read" {
    const alloc = std.testing.allocator;
    var thread = std.Io.Threaded.init(alloc, .{});
    defer thread.deinit();
    const io = thread.io();

    const conn = try db.connectMemory();
    try db.migrate(conn);

    const absolute_dir = "/Users/aidan/Documents/Sample Libraries/ELEKTRON/";
    try saveDir(io, alloc, absolute_dir, conn);

    const sql = "SELECT COUNT(*) FROM SAMPLES";
    const stmt = try db.prepare(conn, sql);
    const res = try db.stmtStep(stmt);
    try expect(res == .Row);
    const count = try db.stmtRead(u64, alloc, stmt, 0);
    try expect(count > 0);
}

test "statement" {
    const conn = try db.connectMemory();
    try db.migrate(conn);

    const stmt = try db.prepare(conn, sample_insert_sql);
    defer db.stmtClose(stmt) catch {};
}
