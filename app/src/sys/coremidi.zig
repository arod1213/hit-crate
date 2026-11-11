const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const midi = @import("coremidi");

pub fn ping(io: Io) !void {
    var port: midi.MIDIPortRef = undefined;
    var client: midi.MIDIClientRef = undefined;

    const client_name_cfstr = newCFString("HitCrate-Output") orelse return error.FailedString;
    defer midi.CFRelease(client_name_cfstr);
    const port_name_cfstr = newCFString("HitCrate-Output") orelse return error.FailedString;
    defer midi.CFRelease(port_name_cfstr);

    if (midi.MIDIClientCreate(client_name_cfstr, null, null, &client) != midi.F_OK) {
        return error.FailedClient;
    }
    if (midi.MIDIOutputPortCreate(client, port_name_cfstr, &port) != midi.F_OK) {
        return error.FailedPort;
    }

    const count = midi.MIDIGetNumberOfSources();
    if (count == 0) {
        std.log.debug("no MIDI sources found", .{});
        return;
    }

    while (true) {
        var pkts: midi.MIDIPacketList = undefined;
        _ = midi.MIDIPacketListInit(&pkts);
        var pkt: midi.MIDIPacket = undefined;
        var data: [265]u8 = @splat(0);
        data[0] = 0x9A;
        data[1] = 60;
        data[2] = 127;
        _ = midi.MIDIPacketListAdd(&pkts, 1, &pkt, 0, 1, &data);

        for (0..count) |id| {
            if (midi.F_OK != midi.MIDISend(port, @intCast(id), &pkts)) {
                return error.FailedMIDISend;
            }
            std.log.debug("sent {d} {d} {d}", .{ data[0], data[1], data[2] });
        }
        try Io.sleep(io, .fromMilliseconds(50), .awake);
    }
}

pub fn setupListener(out_ctx: *MidiCtx) !void {
    var port: midi.MIDIPortRef = undefined;
    var client: midi.MIDIClientRef = undefined;

    const client_name_cfstr = newCFString("HitCrate") orelse return error.FailedString;
    defer midi.CFRelease(client_name_cfstr);
    const port_name_cfstr = newCFString("HitCrate-Input") orelse return error.FailedString;
    defer midi.CFRelease(port_name_cfstr);

    if (midi.MIDIClientCreate(client_name_cfstr, null, null, &client) != midi.F_OK) {
        return error.FailedClient;
    }
    if (midi.MIDIInputPortCreate(client, port_name_cfstr, &eventCallback, out_ctx, &port) != midi.F_OK) {
        return error.FailedPort;
    }

    const count = midi.MIDIGetNumberOfSources();
    if (count == 0) {
        std.log.debug("no MIDI sources found", .{});
        return;
    }
    for (0..count) |id| {
        try clientConnect(id, port);
    }
}

fn clientConnect(id: usize, out_port: midi.MIDIPortRef) !void {
    const source = midi.MIDIGetSource(id);
    var client_name_cfstr: midi.CFStringRef = undefined;
    if (midi.MIDIObjectGetStringProperty(source, midi.kMIDIPropertyName, &client_name_cfstr) != midi.F_OK) {
        return error.NoName;
    }
    defer midi.CFRelease(client_name_cfstr);

    const client_name = midi.CFStringGetCStringPtr(client_name_cfstr, midi.kCFStringEncodingUTF8);
    if (client_name == null) return;
    // std.log.debug("Connected MIDI Client: {s}", .{client_name});

    if (midi.MIDIPortConnectSource(out_port, source, null) != midi.F_OK) {
        return error.FailedConnect;
    }
}

pub const MidiEvent = struct {
    event: u8,
    note: u8,
    velocity: u8,

    pub fn channel(_: MidiEvent) u8 {
        // TODO bitmask properly
        return 0;
    }

    pub fn isNoteOn(self: MidiEvent) bool {
        return (self.event & 0xF0) == 0x90 and self.velocity > 0;
    }

    // TODO: add channel param here
    pub fn noteOn(note: u8) MidiEvent {
        return .{
            .event = 0x9A,
            .note = note,
            .velocity = 127,
        };
    }
};

pub const MidiCtx = struct {
    queue: Io.Queue(MidiEvent),
    io: Io,
};

fn eventCallback(pkt_list: [*c]const midi.MIDIPacketList, ref_ctx: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    if (pkt_list == null) return;
    const ctx: *MidiCtx = @ptrCast(@alignCast((ref_ctx)));

    const count = pkt_list.*.numPackets;
    if (count == 0) return;
    const packet_len = pkt_list.*.packet.len;

    for (0..packet_len) |idx| {
        const pck = pkt_list.*.packet[idx];
        const data = pck.data;
        std.log.debug("event {d} {d} {d}", .{ data[0], data[1], data[2] });
        ctx.queue.putOne(ctx.io, .{ .event = data[0], .note = data[1], .velocity = data[2] }) catch |e| {
            std.log.err("err {}", .{e});
        };
    }
}

fn newCFString(str: [:0]const u8) ?*const midi.struct___CFString {
    return midi.CFStringCreateWithCString(
        null,
        str.ptr,
        midi.kCFStringEncodingUTF8,
    );
}
