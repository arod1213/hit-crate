const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("zigs");
const db = lib.db;
const tui = @import("tui");

const Config = struct {
    db_url: []const u8,
    lock_file: []const u8,

    const Self = @This();

    fn docFolder(io: Io, arena: Allocator, ENV: *const std.process.Environ.Map) ![]const u8 {
        const home = ENV.get("HOME") orelse return error.NoDbPath;
        const doc_folder = try std.fs.path.join(arena, &[_][]const u8{ home, "Documents", "HitCrate" });
        Io.Dir.createDirAbsolute(io, doc_folder, .default_dir) catch |e| switch (e) {
            Io.Dir.CreateDirError.PathAlreadyExists => {},
            else => return e,
        };
        return doc_folder;
    }

    fn db(arena: Allocator, ENV: *const std.process.Environ.Map, doc_folder: []const u8) ![]const u8 {
        if (ENV.get("HIT_CRATE_DB")) |x| {
            if (x.len > 0) return x;
        }
        return try std.fs.path.join(arena, &[_][]const u8{ doc_folder, "hitcrate.db" });
    }

    pub fn fromEnv(io: Io, arena: Allocator, ENV: *const std.process.Environ.Map) !Self {
        const doc_folder = try docFolder(io, arena, ENV);

        const lock_path = try std.fs.path.join(arena, &[_][]const u8{ doc_folder, "scan.lock" });
        var file = try Io.Dir.createFileAbsolute(io, lock_path, .{}); // ensure lock file created
        defer file.close(io);

        return .{
            .db_url = try Self.db(arena, ENV, doc_folder),
            .lock_file = lock_path,
        };
    }
};

const cmd = enum { scan, read, reset, trigger };
pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.arena.allocator();

    const cfg = try Config.fromEnv(io, alloc, init.environ_map);
    const db_url_cstr = try alloc.dupeSentinel(u8, cfg.db_url, 0);

    const args = try init.minimal.args.toSlice(alloc);
    if (args.len < 2) return error.MissingArgs;
    const command = std.meta.stringToEnum(cmd, args[1]) orelse return error.InvalidCommand;

    switch (command) {
        .trigger => {
            try lib.midi.ping(io);
            //
        },
        .reset => {
            const conn = try db.connect(db_url_cstr, false);
            defer db.close(conn);
            try db.exec(conn, "DELETE FROM samples");
            try db.exec(conn, "VACUUM");
        },
        .scan => {
            if (args.len < 3) {
                std.log.err("please provide a folder path to scan", .{});
                return;
            }
            const path = args[2];
            var file = Io.Dir.openFileAbsolute(io, cfg.lock_file, .{ .lock = .exclusive }) catch |e| {
                std.log.err("failed to acquire lock {}", .{e});
                return e;
            };
            defer {
                file.unlock(io);
                file.close(io);
            }

            const conn = try db.connect(db_url_cstr, false);
            defer db.close(conn);
            try db.migrate(conn);

            try lib.scanner.saveDir(io, path, conn);
        },
        .read => {
            var use_midi = false;
            for (args) |arg| {
                if (std.mem.eql(u8, arg, "-m")) {
                    use_midi = true;
                    break;
                }
            }

            const conn = try db.connect(db_url_cstr, true);
            defer db.close(conn);
            ////////////////////////
            // I/O setup
            ////////////////////////
            var buffer: [256]u8 = undefined;
            const stdin = Io.File.stdin();
            var rdr = stdin.reader(io, &buffer);

            var term = try tui.input.Termios.init(stdin.handle);
            try term.singleChar();
            defer term.deinit() catch {};

            var out_buffer: [256]u8 = undefined;
            const stdout = Io.File.stdout();
            var wrt = stdout.writer(io, &out_buffer);
            // var dbg = std.heap.DebugAllocator(.{ .verbose_log = true }).init;
            // defer {
            //     const leak_count = dbg.detectLeaks();
            //     std.log.debug("found {d} leaks", .{leak_count});
            //     const res = dbg.deinit();
            //     if (res == .leak) {
            //         @panic("LEAKED");
            //     }
            // }
            try read(io, init.gpa, conn, &rdr.interface, &wrt.interface, use_midi);
        },
    }
}

fn read(io: Io, gpa: Allocator, conn: lib.db.Connection, rdr: *Io.Reader, wrt: *Io.Writer, use_midi: bool) !void {
    const engine = try lib.ma.Engine.init(gpa);
    defer engine.deinit(gpa);

    var search_text = try std.ArrayList(u8).initCapacity(gpa, 10);
    defer search_text.deinit(gpa);

    var midi_buff: [80]lib.midi.MidiEvent = undefined;
    var app = tui.App{
        .limit = 10,
        .page = 0,
        .idx = 0,
        .samples = &[0]lib.SampleEntry{},
        .midi_ctx = lib.midi.MidiCtx{
            .io = io,
            .queue = Io.Queue(lib.midi.MidiEvent).init(&midi_buff),
        },
        .engine = engine,
        .search_text = search_text,
        .params = lib.SearchParams{
            .search_text = "",
        },
    };
    defer {
        app.midi_ctx.queue.close(io);
        for (app.sequencer_samples) |sample| {
            if (sample) |s| {
                s.deinitOwned(gpa);
            }
        }
    }

    var sample_list_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer sample_list_arena.deinit();
    const sample_list_arena_alloc = sample_list_arena.allocator();
    app.samples = try lib.querySamples(sample_list_arena_alloc, conn, app.params, app.limit, app.page);

    ////////////////////////
    // PLAYBACK
    ////////////////////////
    if (use_midi) try lib.midi.setupListener(&app.midi_ctx);

    // used for key command / midi triggers to update UI / shown samples
    var cmd_buffer: [80]tui.sync.CommandType = undefined;
    var cmd_queue = tui.sync.CommandQueue.init(&cmd_buffer);
    defer cmd_queue.close(io);

    const audio_alloc = std.heap.smp_allocator;
    var fut_audio = try io.concurrent(tui.playback.listen, .{ audio_alloc, io, &app });
    defer fut_audio.cancel(io);

    var fut_keys = try io.concurrent(tui.keys.listen, .{ io, gpa, &app, rdr, &cmd_queue });
    defer fut_keys.cancel(io);

    ////////////////////////
    // RENDERING
    ////////////////////////
    while (true) {
        try app.mu.lock(io);
        errdefer app.mu.unlock(io);
        try tui.render(wrt, &app);
        app.mu.unlock(io);

        // only loops if no_ops are sent
        while (true) {
            const cmd_type = try cmd_queue.getOne(io);
            switch (cmd_type) {
                .no_op => continue,
                .key => {},
                .fetch => {
                    try app.mu.lock(io);
                    defer app.mu.unlock(io);
                    _ = sample_list_arena.reset(.free_all);
                    app.samples = try lib.querySamples(sample_list_arena_alloc, conn, app.params, app.limit, app.page);
                },
            }
            break;
        }
    }
}
