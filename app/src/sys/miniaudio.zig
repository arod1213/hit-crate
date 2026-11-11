const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const ma = @import("miniaudio");

pub const Decoder = struct {
    ptr: *ma.ma_decoder,
    sr: u32,
    in_ch: u32,
    out_ch: u32,
    format: ma.ma_format,
    const Self = @This();
    pub const MAX_CHANNELS = 8;

    pub fn init(alloc: Allocator, path: [:0]const u8, channels: u32, sample_rate: u32) !Self {
        if (sample_rate == 0) return error.UnsupportedFormat;
        if (channels > Self.MAX_CHANNELS) return error.UnsupportedFormat;
        if (channels == 0) return error.NoChannels;

        const ptr = try alloc.create(ma.ma_decoder);
        errdefer alloc.destroy(ptr);

        const format = ma.ma_format_f32;
        const config = ma.ma_decoder_config_init(format, channels, sample_rate);

        const res = ma.ma_decoder_init_file(path, &config, ptr);
        if (res != ma.MA_SUCCESS) return error.NoDecoder;

        // assert(@as(u32, @intCast(ptr.outputChannels)) == channels);
        return .{
            .ptr = ptr,
            .sr = sample_rate,
            .in_ch = channels,
            .out_ch = @intCast(ptr.outputChannels),
            .format = format,
        };
    }

    pub fn readFrames(self: *Self, out: []f32, frame_count: usize) !usize {
        var frames_read: ma.ma_uint64 = undefined;
        const res = self.ptr.ma_decoder_read_pcm_frames(
            @ptrCast(out),
            @intCast(frame_count),
            &frames_read,
        );
        switch (res) {
            ma.MA_SUCCESS, ma.MA_AT_END => {},
            else => return error.FailedRead,
        }
        return @intCast(frames_read);
    }

    pub fn deinit(self: *Self, alloc: Allocator) void {
        _ = self.ptr.uninit();
        alloc.destroy(self.ptr);
    }

    pub fn durationMs(self: Self) !u64 {
        const frames = try self.totalFrames();
        return frames * 1000 / @as(u64, self.sr);
    }

    pub fn totalFrames(self: Self) !u64 {
        var length: c_ulonglong = undefined;
        const res = self.ptr.ma_decoder_get_length_in_pcm_frames(&length);
        if (res != ma.MA_SUCCESS) return error.NoLength;
        return @intCast(length);
    }
};

pub const Engine = struct {
    ptr: *ma.ma_engine,

    const Self = @This();

    pub fn init(alloc: Allocator) !Self {
        const engine = try alloc.create(ma.ma_engine);
        errdefer alloc.destroy(engine);
        const res = ma.ma_engine_init(null, engine);
        if (res != ma.MA_SUCCESS) return error.NoOpen;
        return .{ .ptr = engine };
    }

    pub fn deinit(self: Self, alloc: Allocator) void {
        self.ptr.uninit();
        alloc.destroy(self.ptr);
    }
};

pub const Sound = struct {
    ptr: *ma.ma_sound,
    // TODO: maybe add fullpath here to check for equality?

    const Self = @This();

    pub fn init(alloc: Allocator, engine: [*c]ma.ma_engine, path: [:0]const u8) !Self {
        assert(engine != null);

        const sound = try alloc.create(ma.ma_sound);
        errdefer alloc.destroy(sound);

        const res = engine.*.ma_sound_init_from_file(
            path,
            ma.MA_SOUND_FLAG_DECODE | ma.MA_SOUND_FLAG_STREAM,
            null,
            null,
            sound,
        );
        if (res != ma.MA_SUCCESS) {
            std.log.err("failed {d}: {s}", .{ res, path });
            return error.NoOpen;
        }
        return .{
            .ptr = sound,
        };
    }

    pub fn setGain(self: Self, amp: f32) void {
        self.ptr.set_volume(amp);
    }

    pub fn setPitch(self: Self, semitones: f32) void {
        const float_mult = std.math.pow(f32, 2.0, semitones / 12.0);
        self.ptr.set_pitch(float_mult);
    }

    pub fn seek(self: Self, frame: u64) !void {
        if (self.ptr.seek_to_pcm_frame(frame) != ma.MA_SUCCESS) return error.FailedSeek;
    }

    pub fn play(self: Self) !void {
        const res = self.ptr.start();
        if (res != ma.MA_SUCCESS) return error.NoPlay;
    }

    pub fn isPlaying(self: Self) bool {
        const res = self.ptr.is_playing();
        return res == ma.MA_TRUE;
    }

    pub fn stop(self: Self) !void {
        const res = self.ptr.stop();
        if (res != ma.MA_SUCCESS) return error.NoStop;
    }

    pub fn deinit(self: Self, alloc: Allocator) void {
        self.stop() catch {};
        self.ptr.uninit();
        alloc.destroy(self.ptr);
    }
};
