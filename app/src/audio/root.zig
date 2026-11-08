const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;

const eb = @import("ebur128");
const kfft = @import("kissfft");

const ma = @import("../sys/miniaudio.zig");

pub const AudioExt = enum {
    wav,
    WAV,
    // mp3,
    // aif,
    // aiff,

    pub fn fromPath(path: []const u8) ?AudioExt {
        const ext = std.fs.path.extension(path);
        if (ext.len == 0) return null;
        return std.meta.stringToEnum(AudioExt, ext[1..]);
    }
};

pub const Sample = struct {
    fullpath: []const u8,
    basename: []const u8,
    sample_rate: u32,
    channels: u32,
    ext: AudioExt,
    duration_ms: u64,
    rms: f32,
    lufs: ?f64,
    true_peak: ?f64,
    width: f32,
    centroid: ?f32,
};

pub const AudioMeta = struct {
    lufs: ?f64,
    true_peak: ?f64,
    centroid: ?f32,
    width: f32,
    rms: f32,

    const Self = @This();

    pub fn fromDecoder(
        gpa: Allocator,
        decoder: *ma.Decoder,
        max_read_ms: u64,
    ) !Self {
        var meta_list = try std.ArrayList(Self).initCapacity(gpa, 25);
        defer meta_list.deinit(gpa);

        const eb_state = eb.ebur128_init(
            decoder.out_ch,
            decoder.sr,
            eb.EBUR128_MODE_I | eb.EBUR128_MODE_TRUE_PEAK,
        );
        if (eb_state == null) return error.FailedDecoder;
        defer eb.ebur128_destroy(@constCast(&eb_state));

        const FRAME_SIZE = 4096;
        var buffer: [FRAME_SIZE * ma.Decoder.MAX_CHANNELS]f32 = undefined;

        var all_frames = try std.ArrayList(f32).initCapacity(gpa, FRAME_SIZE * ma.Decoder.MAX_CHANNELS * 4);
        defer all_frames.deinit(gpa);

        var max_width: f32 = 0;

        var total_frames_read: u64 = 0;
        while (totalReadMs(total_frames_read, @as(u64, decoder.sr)) < max_read_ms) {
            const frames_read = try decoder.readFrames(&buffer, FRAME_SIZE);
            total_frames_read += frames_read;

            const frames = buffer[0 .. frames_read * decoder.out_ch];

            _ = eb.ebur128_add_frames_float(
                eb_state,
                @ptrCast(frames),
                @intCast(frames_read),
            );
            max_width = @max(max_width, widthFrames(gpa, frames, decoder.out_ch) catch 0);

            try all_frames.appendSlice(gpa, frames);
            if (frames_read < FRAME_SIZE) break;
        }

        const true_peak: ?f64 = blk: {
            const l = truePeak(eb_state, 0) catch break :blk null;
            if (decoder.out_ch > 1) {
                const r = truePeak(eb_state, 1) catch {
                    break :blk l;
                };
                break :blk @max(l, r);
            }
            break :blk l;
        };

        const rms = ampToDb(f32, rmsAmp(all_frames.items));
        const centroid = spectralCentroid(gpa, all_frames.items, decoder.sr, decoder.out_ch) catch null;
        const lufs = blk: {
            var loudness_lufs: f64 = 0.0;
            if (eb.ebur128_loudness_global(eb_state, &loudness_lufs) != eb.EBUR128_SUCCESS) {
                break :blk null;
            }
            break :blk if (loudness_lufs < -60.0) null else loudness_lufs;
        };

        return Self{
            .rms = rms,
            .centroid = centroid,
            .width = max_width,
            .lufs = lufs,
            .true_peak = true_peak,
        };
    }
};

pub fn spectralCentroid(gpa: Allocator, frames: []const f32, sr: usize, ch: usize) !f32 {
    assert(ch != 0);
    assert(sr != 0);

    const num_frames = @divFloor(frames.len, ch);

    var mono_frames = try gpa.alloc(kfft.kiss_fft_cpx, num_frames);
    defer gpa.free(mono_frames);

    // collapse to mono
    var i: usize = 0;
    var window = std.mem.window(f32, frames, ch, ch);
    while (window.next()) |set| {
        if (i >= num_frames) break;
        var sum: f32 = 0;
        for (set) |s| sum += s;
        const mono = sum / @as(f32, @floatFromInt(ch));
        mono_frames[i] = .{ .r = mono, .i = 0 };
        i += 1;
    }

    assert(num_frames <= mono_frames.len);
    const BIN_WIDTH = 1024;
    var bins = std.mem.zeroes([BIN_WIDTH]kfft.kiss_fft_cpx);

    const cfg = kfft.kiss_fft_alloc(BIN_WIDTH, 0, null, 0) orelse {
        return error.FFTAllocFailed;
    };
    defer kfft.kiss_fft_free(cfg);

    kfft.kiss_fft(cfg, @ptrCast(mono_frames), bins[0..].ptr);
    var weighted_sum: f32 = 0;
    var mag_sum: f32 = 0;

    const half = @divFloor(BIN_WIDTH, 2);
    for (0..half + 1) |k| {
        const re: f32 = bins[k].r;
        const im: f32 = bins[k].i;

        const mag = @sqrt(re * re + im * im);
        const freq = @as(f32, @floatFromInt(k)) * @as(f32, @floatFromInt(sr)) /
            @as(f32, @floatFromInt(BIN_WIDTH));

        weighted_sum += freq * mag;
        mag_sum += mag;
    }

    if (mag_sum == 0) return 0;
    return weighted_sum / mag_sum;
}

/// return in amp
fn rmsAmp(frames: []f32) f32 {
    if (frames.len == 0) return 0;
    const count = frames.len;
    var sum: f32 = 0;
    for (frames) |f| {
        sum += f * f;
    }
    const div = sum / @as(f32, @floatFromInt(count));
    return @sqrt(div);
}

fn truePeak(state: [*c]eb.ebur128_state, ch: usize) !f64 {
    var val: f64 = undefined;
    const res = eb.ebur128_true_peak(state, @intCast(ch), &val);
    if (res != eb.EBUR128_SUCCESS) {
        return error.NoPeak;
    }
    return val;
}

fn nullFloor(comptime T: type, val: T, floor: T) ?T {
    if (val < floor) {
        return null;
    }
    return val;
}

fn totalReadMs(frames_read: u64, sr: u64) u64 {
    if (sr == 0) return 0;
    return 1_000 * frames_read / sr;
}

pub fn ampToTarget(comptime T: type, lufs: T, target: T) T {
    const diff = target - lufs;
    return dbToAmp(T, diff);
}

pub fn ampToDb(comptime T: type, amp: T) T {
    return 20.0 * @log10(amp);
}

pub fn dbToAmp(comptime T: type, db: T) T {
    return std.math.pow(T, 10.0, (db / 20.0));
}

fn widthCompare(a: f32, b: f32) f32 {
    const total_amp = @abs(a) + @abs(b);
    if (total_amp == 0) return 0;
    const a_percent = a / total_amp;
    const b_percent = b / total_amp;
    const makeup = @abs(a_percent + b_percent);
    return makeup;
}

fn avgWidth(vals: []const f32) f32 {
    var sum: f32 = 0.0;
    for (vals) |val| {
        sum += val;
    }
    const avg: f32 = sum / @as(f32, @floatFromInt(vals.len));
    const scale: f32 = @round((1.0 - avg) * 1000.0);
    return scale / 10.0 * 2.0;
}

pub fn widthFrames(alloc: Allocator, frames: []const f32, ch: usize) !f32 {
    var width_list = try std.ArrayList(f32).initCapacity(alloc, 50);
    defer width_list.deinit(alloc);
    var window = std.mem.window(f32, frames, ch, ch);
    while (window.next()) |set| {
        if (set.len != 2) {
            break;
        }
        const width_val = widthCompare(set[0], set[1]);
        try width_list.append(alloc, width_val);
    }
    return avgWidth(width_list.items);
}

// TESTS

test "db to amp" {
    try std.testing.expect(1 == dbToAmp(f32, 0));
}
test "lufs to target" {
    try std.testing.expect(1 == ampToTarget(f32, -14.0, -14.0));
}

test "width comparison" {
    assert(widthCompare(0.0, 0.0) == 0.0);
}
