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

    const args = try init.minimal.args.toSlice(alloc);
    if (args.len < 3) return error.MissingArgs;
    const command = std.meta.stringToEnum(cmd, args[1]) orelse return error.InvalidCommand;
    const path = args[2];

    switch (command) {
        .scan => {
            const conn = try db.connect("test.db", false);
            defer db.close(conn);
            try lib.scanner.saveDir(io, path, conn);
        },
        .read => {
            const conn = try db.connect("test.db", true);
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

            const engine = try lib.ma.engineNew(alloc);
            defer lib.ma.engineClose(engine);

            var search = try std.ArrayList(u8).initCapacity(alloc, 10);
            defer search.deinit(alloc);

            var app = tui.App{
                .limit = 10,
                .page = 0,
                .idx = 0,
                .samples = &[0]lib.SampleEntry{},
                .engine = engine,
                .search_text = search,
                .params = lib.SearchParams{
                    .search_name = "kick",
                },
            };
            defer {
                if (app.sound) |snd| {
                    lib.ma.soundStop(snd) catch {};
                    lib.ma.soundClose(snd);
                }
            }

            var render_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer render_arena.deinit();
            const render_alloc = render_arena.allocator();
            while (true) {
                app.params.search_name = app.search_text.items;
                app.samples = try lib.querySamples(render_alloc, conn, app.params, app.limit, app.page);
                defer _ = render_arena.reset(.free_all);

                try tui.render(&wrt.interface, &app);
                try tui.handleKeys(alloc, &app, &rdr.interface);
            }
        },
    }
}
