const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const Wave = extern struct {
    fmt: Fmt,
    data_size: u32,

    const Self = @This();

    pub fn fromFilePath(io: Io, fullpath: []const u8) !Self {
        var file = try Io.Dir.openFileAbsolute(io, fullpath, .{
            .mode = .read_only,
        });
        defer file.close(io);
        return Self.fromFile(io, &file);
    }

    pub fn fromFile(io: Io, f: *Io.File) !Self {
        var buffer: [4096]u8 = undefined;
        var rdr = f.reader(io, &buffer);

        var header: Header = undefined;
        try rdr.interface.readSliceAll(std.mem.asBytes(&header));

        if (!std.mem.eql(u8, "RIFF", &header.chunk_id)) return error.BadHeader;
        if (!std.mem.eql(u8, "WAVE", &header.format)) return error.BadHeader;

        var wav: Self = std.mem.zeroes(Self);

        while (true) {
            var chunk: Chunk = undefined;
            try rdr.interface.readSliceAll(std.mem.asBytes(&chunk));
            const seek_by = blk: {
                if (std.mem.eql(u8, &chunk.id, "data")) {
                    wav.data_size = chunk.size;
                    break;
                } else if (std.mem.eql(u8, &chunk.id, "fmt ")) {
                    var fmt: Fmt = undefined;
                    try rdr.interface.readSliceAll(std.mem.asBytes(&fmt));
                    wav.fmt = fmt;
                    break :blk chunk.size - @sizeOf(Fmt);
                } else {
                    break :blk chunk.size;
                }
            };
            try rdr.seekBy(seek_by);
            if (seek_by % 2 == 1) try rdr.seekBy(1);
        }
        return wav;
    }

    pub fn durationMs(self: Self) u64 {
        if (self.fmt.byte_rate == 0) return 0;
        return 1000 * @as(u64, @intCast(std.math.divCeil(
            u32,
            self.data_size,
            self.fmt.byte_rate,
        ) catch 0));
    }
};

const Header = extern struct {
    // RIFF Chunk Descriptor
    chunk_id: [4]u8,
    chunk_size: u32,
    format: [4]u8,
};

const Chunk = extern struct {
    id: [4]u8,
    size: u32,
};

const Fmt = extern struct {
    audio_format: u16,
    num_channels: u16,
    sample_rate: u32,
    byte_rate: u32,
    block_align: u16,
    bits_per_sample: u16,
};
