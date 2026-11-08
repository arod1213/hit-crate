const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const Termios = struct {
    handle: std.posix.fd_t,
    original: std.posix.termios,
    current: std.posix.termios,
    const Self = @This();

    pub fn init(handle: std.posix.fd_t) !Self {
        const vals = try std.posix.tcgetattr(handle);
        return .{
            .handle = handle,
            .current = vals,
            .original = vals,
        };
    }
    pub fn deinit(self: *Self) !void {
        _ = try std.posix.tcsetattr(self.handle, std.posix.TCSA.NOW, self.original);
    }

    pub fn singleChar(self: *Self) !void {
        self.current.lflag.ICANON = false;
        self.current.lflag.ECHO = false;
        _ = try std.posix.tcsetattr(self.handle, std.posix.TCSA.NOW, self.current);
    }
};

// tag value == ascii - '0', arrows + space live past the printable range
pub const KeyCode = enum(u8) {
    @"0" = '0' - '0',
    @"1",
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",

    A = 'A' - '0',
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,

    a = 'a' - '0',
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,

    left = 0xF0,
    right,
    down,
    up,
    space,
    forward_slash,
    back_slash,

    pub fn parse(rdr: *Io.Reader) !?KeyCode {
        const b = try rdr.takeByte();

        switch (b) {
            ' ' => return .space,
            '/' => return .forward_slash,
            '\\' => return .back_slash,
            0x1B => {
                if (rdr.bufferedLen() == 0) return null;
                switch (try rdr.takeByte()) {
                    '[', 'O' => {},
                    else => return null,
                }
                return switch (try rdr.takeByte()) {
                    'A' => .up,
                    'B' => .down,
                    'C' => .right,
                    'D' => .left,
                    else => null,
                };
            },
            else => {
                if (b < '0') return null;
                return std.enums.fromInt(KeyCode, b - '0');
            },
        }
    }
};
