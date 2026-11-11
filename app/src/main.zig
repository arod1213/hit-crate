const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("zigs");
const db = lib.db;
const tui = @import("tui");

const cmd = enum { scan, read, reset };

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

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.arena.allocator();

    const cfg = try Config.fromEnv(io, alloc, init.environ_map);
    const db_url_cstr = try alloc.dupeSentinel(u8, cfg.db_url, 0);

    const args = try init.minimal.args.toSlice(alloc);
    if (args.len < 3) return error.MissingArgs;
    const command = std.meta.stringToEnum(cmd, args[1]) orelse return error.InvalidCommand;
    const path = args[2];

    switch (command) {
        .reset => {
            const conn = try db.connect(db_url_cstr, false);
            defer db.close(conn);
            try db.exec(conn, "DELETE FROM samples");
            try db.exec(conn, "VACUUM");
        },
        .scan => {
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
        .read => try read(io, alloc, db_url_cstr),
    }
}

fn read(io: Io, arena: Allocator, db_url: [:0]const u8) !void {
    const conn = try db.connect(db_url, true);
    defer db.close(conn);

    var buffer: [256]u8 = undefined;
    const stdin = Io.File.stdin();
    var rdr = stdin.reader(io, &buffer);

    var term = try tui.input.Termios.init(stdin.handle);
    try term.singleChar();
    defer term.deinit() catch {};

    var out_buffer: [256]u8 = undefined;
    const stdout = Io.File.stdout();
    var wrt = stdout.writer(io, &out_buffer);

    const engine = try lib.ma.Engine.init(arena);
    defer engine.deinit(arena);

    var search_text = try std.ArrayList(u8).initCapacity(arena, 10);
    defer search_text.deinit(arena);

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
            .search_text = "kick",
        },
    };
    defer app.midi_ctx.queue.close(io);

    try lib.midi.setupListener(&app.midi_ctx);
    var fut = try io.concurrent(tui.playback.playbackQueue, .{ arena, io, &app });
    defer fut.cancel(io);

    try app.publishSelection(std.heap.smp_allocator); // init first sound (use other alloc to let other thread free it)

    var render_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer render_arena.deinit();
    const render_alloc = render_arena.allocator();

    var depth: tui.RenderDepth = .all;
    while (true) {
        app.params.search_text = app.search_text.items;
        if (depth == .all) {
            _ = render_arena.reset(.free_all);
            app.samples = try lib.querySamples(render_alloc, conn, app.params, app.limit, app.page);
        }

        try tui.render(&wrt.interface, &app);
        depth = try tui.handleKeys(io, arena, &app, &rdr.interface);
    }
}
