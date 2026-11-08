const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const sqlite = @import("sqlite");

pub const Connection = ?*sqlite.struct_sqlite3;
pub const Statement = ?*sqlite.struct_sqlite3_stmt;

pub fn connect(url: [:0]const u8, read_only: bool) !Connection {
    var db: Connection = null;
    const flag = if (read_only) sqlite.SQLITE_OPEN_READONLY else sqlite.SQLITE_OPEN_READWRITE | sqlite.SQLITE_OPEN_CREATE;
    const res = sqlite.sqlite3_open_v2(url, &db, flag, null);
    if (res != sqlite.SQLITE_OK) {
        std.log.err("failed db open: {d}", .{res});
        return error.FailedOpen;
    }
    assert(db != null);
    return db;
}

pub fn close(conn: Connection) void {
    if (conn) |db| {
        _ = db.close();
    }
}

pub fn exec(conn: Connection, sql: [:0]const u8) !void {
    const res = sqlite.sqlite3_exec(conn, sql, null, null, null);
    if (res != sqlite.SQLITE_OK) {
        std.log.err("failed exec: {d}", .{res});
        return error.FailedExec;
    }
}

pub fn txStart(conn: Connection) !void {
    const sql = "BEGIN";
    const res = sqlite.sqlite3_exec(conn, sql, null, null, null);
    if (res != sqlite.SQLITE_OK) {
        std.log.err("failed tx setup: {d}", .{res});
        return error.FailedBegin;
    }
}

pub fn txRollback(conn: Connection) void {
    const sql = "ROLLBACK";
    _ = sqlite.sqlite3_exec(conn, sql, null, null, null);
}

pub fn txCommit(conn: Connection) !void {
    const sql = "COMMIT";
    const res = sqlite.sqlite3_exec(conn, sql, null, null, null);
    if (res != sqlite.SQLITE_OK) {
        std.log.err("failed tx commit: {d}", .{res});
        return error.FailedBegin;
    }
}

pub fn stmtReadMany(alloc: Allocator, stmt: Statement, ptrs: anytype) !void {
    const ArgsType = @TypeOf(ptrs);
    const info = @typeInfo(ArgsType);
    assert(info == .@"struct");

    const field_names = info.@"struct".field_names;
    const field_types = info.@"struct".field_types;

    const column_count = stmt.?.sqlite3_data_count();
    if (@as(usize, @intCast(column_count)) != field_names.len) {
        @panic("SQL columns != provided output columns");
    }

    inline for (field_names, 0..) |name, idx| {
        const T = field_types[idx];
        const field_info = @typeInfo(T);
        assert(field_info == .pointer);
        const val = try stmtRead(field_info.pointer.child, alloc, stmt, idx);
        @field(ptrs, name).* = val;
    }
}

pub fn stmtRead(comptime T: type, alloc: Allocator, stmt: Statement, idx: usize) !T {
    const index: c_int = @intCast(idx);
    const info = @typeInfo(T);
    switch (info) {
        .optional => |x| {
            return stmtRead(x.child, alloc, stmt, idx) catch null;
        },
        .pointer => |ptr| {
            if (ptr.size == .slice and ptr.child == u8) {
                const txt = sqlite.sqlite3_column_text(
                    stmt,
                    index,
                );
                if (txt == null) return error.NullStr;
                return alloc.dupe(u8, std.mem.span(txt));
            }
            if (ptr.size == .one) {
                const child = @typeInfo(ptr.child);
                if (child == .array and child.array.child == u8) {
                    const txt = sqlite.sqlite3_column_text(
                        stmt,
                        index,
                    );
                    if (txt == null) return error.NullStr;
                    return alloc.dupe(u8, std.mem.span(txt));
                }
            }
            std.log.err("child type is {}", .{ptr.child});
            @panic("invalid data type");
        },
        .bool => {
            const res = sqlite.sqlite3_column_int(stmt, index);
            switch (res) {
                0 => return false,
                1 => return true,
                else => return error.InvalidBool,
            }
        },
        .float, .comptime_float => return @floatCast(sqlite.sqlite3_column_double(stmt, index)),
        .int, .comptime_int => return if (T == i64 or T == u64)
            sqlite.sqlite3_column_int64(stmt, index)
        else
            sqlite.sqlite3_column_int(stmt, index),
        else => @panic("unsupported data type"),
    }
}

pub fn prepare(conn: Connection, sql: [:0]const u8) !Statement {
    assert(conn != null);
    var stmt: Statement = undefined;

    const res = sqlite.sqlite3_prepare(conn, sql, @intCast(sql.len), &stmt, null);
    if (res != sqlite.SQLITE_OK) {
        std.log.err("failed prepare: {d}", .{res});
        return error.FailedPrepare;
    }
    assert(stmt != null);
    return stmt;
}

pub fn stmtBindMany(stmt: Statement, args: anytype) !void {
    const ArgsType = @TypeOf(args);
    const info = @typeInfo(ArgsType);
    assert(info == .@"struct");

    const field_names = info.@"struct".field_names;
    const field_types = info.@"struct".field_types;
    inline for (field_names, 0..) |name, idx| {
        const T = field_types[idx];
        const val = @field(args, name);
        stmtBind(T, stmt, val, idx + 1) catch |e| {
            std.log.err("fucking err on {d}: {}: {}", .{ idx + 1, T, e });
            return e;
        };
    }
}

pub fn stmtBind(comptime T: type, stmt: Statement, val: T, idx: usize) !void {
    assert(idx > 0);
    const index: c_int = @intCast(idx);
    const info = @typeInfo(T);
    const res = switch (info) {
        .optional => |x| if (val == null) sqlite.sqlite3_bind_null(stmt, index) else return try stmtBind(x.child, stmt, val.?, idx),
        .pointer => |ptr| blk: {
            if (ptr.size == .slice and ptr.child == u8) {
                break :blk sqlite.sqlite3_bind_text(
                    stmt,
                    index,
                    val.ptr,
                    @intCast(val.len),
                    null,
                );
            }
            if (ptr.size == .one) {
                const child = @typeInfo(ptr.child);
                if (child == .array and child.array.child == u8) {
                    break :blk sqlite.sqlite3_bind_text(
                        stmt,
                        index,
                        val,
                        @intCast(val.len),
                        null,
                    );
                }
            }
            std.log.err("child type is {}", .{ptr.child});
            @panic("invalid data type");
        },
        .bool => sqlite.sqlite3_bind_int64(stmt, index, if (val) 1 else 0),
        .float, .comptime_float => sqlite.sqlite3_bind_double(stmt, index, @floatCast(val)),
        .int, .comptime_int => if (T == i64 or T == u64)
            sqlite.sqlite3_bind_int64(stmt, index, @intCast(val))
        else
            sqlite.sqlite3_bind_int(stmt, index, @intCast(val)),
        else => @panic("unsupported data type"),
    };
    if (res != sqlite.SQLITE_OK) {
        std.log.err("failed bind: {d}", .{res});
        return error.FailedBind;
    }
}

const StmtState = enum { Done, Row };
pub fn stmtStep(stmt: Statement) !StmtState {
    const res = sqlite.sqlite3_step(stmt);
    return switch (res) {
        sqlite.SQLITE_ROW => .Row,
        sqlite.SQLITE_DONE => .Done,
        else => {
            std.log.err("failed step: {d}", .{res});
            return error.FailedStep;
        },
    };
}

pub fn stmtReset(stmt: Statement) !void {
    const res = sqlite.sqlite3_reset(stmt);
    if (res != sqlite.SQLITE_OK) {
        std.log.err("failed stmt reset: {d}", .{res});
        return error.FailedReset;
    }
}

pub fn stmtClose(stmt: Statement) !void {
    const res = sqlite.sqlite3_finalize(stmt);
    if (res != sqlite.SQLITE_OK) {
        std.log.err("failed finalize: {d}", .{res});
        return error.FailedClose;
    }
}
