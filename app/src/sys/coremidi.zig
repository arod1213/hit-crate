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
    std.log.debug("found {d} MIDI sources", .{count});
    for (0..count) |id| {
        std.log.debug("connecting {d}", .{id});
        try clientConnect(id, port);
    }
}

fn clientConnect(id: usize, out_port: midi.MIDIPortRef) !void {
    const source = midi.MIDIGetSource(id);
    if (midi.MIDIPortConnectSource(out_port, source, null) != midi.F_OK) {
        return error.FailedConnect;
    }

    var client_name_cfstr: midi.CFStringRef = undefined;
    if (midi.MIDIObjectGetStringProperty(source, midi.kMIDIPropertyName, &client_name_cfstr) != midi.F_OK) {
        return error.NoName;
    }
    defer midi.CFRelease(client_name_cfstr);

    const client_name = midi.CFStringGetCStringPtr(client_name_cfstr, midi.kCFStringEncodingUTF8);
    if (client_name != null) {
        std.log.debug("Connected MIDI Client: {s}", .{client_name});
    } else {
        std.log.debug("No name for MIDI client: {d}", .{id});
    }
}

pub const MidiEvent = struct {
    timestamp: i96,
    event: u8,
    note: u8,
    velocity: u8,

    pub fn channel(self: MidiEvent) u8 {
        return self.event & 0x0F;
    }

    pub fn isNoteOn(self: MidiEvent) bool {
        return (self.event & 0xF0) == 0x90 and self.velocity > 0;
    }

    // TODO: add channel param here
    pub fn noteOn(chan: u8, note: u8, timestamp: i96) MidiEvent {
        return .{
            .event = 0x90 | (chan & 0x0F),
            .note = note,
            .velocity = 127,
            .timestamp = timestamp,
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
    // const packet_len = pkt_list.*.packet.len;

    var pck: *const midi.MIDIPacket = @ptrCast(&pkt_list.*.packet[0]);
    for (0..count) |_| {
        parsePacket(ctx, pck.data[0..pck.length], @intCast(pck.timeStamp));
        const next = pck.MIDIPacketNext();
        if (next == null) break;
        pck = next;
    }
}

fn parsePacket(ctx: *MidiCtx, data: []const u8, timestamp: i96) void {
    var status: u8 = 0; // last status byte, for running status
    var i: usize = 0;
    while (i < data.len) {
        const b = data[i];

        // real-time (clock/start/stop): always 1 byte, can appear anywhere
        if (b >= 0xF8) {
            i += 1;
            continue;
        }

        // new status byte; otherwise b is a data byte reusing the last status
        if (b >= 0x80) {
            status = b;
            i += 1;
        }

        const data_len: usize = switch (status & 0xF0) {
            0x80, 0x90, 0xA0, 0xB0, 0xE0 => 2,
            0xC0, 0xD0 => 1,
            // sysex / system common: not handled, drop the rest of the packet
            0xF0 => return,
            // no status seen yet, stray data bytes
            else => return,
        };
        if (i + data_len > data.len) return; // truncated message

        const event: MidiEvent = .{
            .event = status,
            .note = data[i],
            .velocity = if (data_len == 2) data[i + 1] else 0,
            .timestamp = timestamp,
        };
        i += data_len;

        ctx.queue.putOne(ctx.io, event) catch |e| {
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
