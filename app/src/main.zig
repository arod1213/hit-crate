const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const lib = @import("zigs");
const db = lib.db;
const tui = @import("tui");

const cmd = enum { scan, read };

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.arena.allocator();

    const db_url = init.environ_map.get("HIT_CRATE_DB") orelse return error.MissingDB;
    const db_url_cstr = try alloc.dupeSentinel(u8, db_url, 0);

    const args = try init.minimal.args.toSlice(alloc);
    if (args.len < 3) return error.MissingArgs;
    const command = std.meta.stringToEnum(cmd, args[1]) orelse return error.InvalidCommand;
    const path = args[2];

    switch (command) {
        .scan => {
            const conn = try db.connect(db_url_cstr, false);
            defer db.close(conn);
            try db.migrate(conn);

            try lib.scanner.saveDir(io, path, conn);
        },
        .read => {
            const conn = try db.connect(db_url_cstr, true);
            defer db.close(conn);
            // try db.migrate(conn);

            var buffer: [256]u8 = undefined;
            const stdin = Io.File.stdin();
            var rdr = stdin.reader(io, &buffer);

            var term = try tui.input.Termios.init(stdin.handle);
            try term.singleChar();
            defer term.deinit() catch {};

            var out_buffer: [256]u8 = undefined;
            const stdout = Io.File.stdout();
            var wrt = stdout.writer(io, &out_buffer);

            const engine = try lib.ma.engineNew(alloc);
            defer lib.ma.engineClose(alloc, engine);

            var search_text = try std.ArrayList(u8).initCapacity(alloc, 10);
            defer search_text.deinit(alloc);

            var app = tui.App{
                .limit = 10,
                .page = 0,
                .idx = 0,
                .samples = &[0]lib.SampleEntry{},
                .engine = engine,
                .search_text = search_text,
                .params = lib.SearchParams{
                    .search_text = "kick",
                },
            };
            defer {
                if (app.sound) |snd| {
                    lib.ma.soundStop(snd) catch {};
                    lib.ma.soundClose(alloc, snd);
                }
            }

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
                depth = try tui.handleKeys(io, alloc, &app, &rdr.interface);
            }
        },
    }
}
