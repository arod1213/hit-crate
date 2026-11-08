const std = @import("std");

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
