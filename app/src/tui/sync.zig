const std = @import("std");
const Io = std.Io;

pub const CommandQueue = Io.Queue(CommandType);
pub const CommandType = enum { no_op, key, fetch };
