const std = @import("std");
const f = @import("file.zig");
const dm = @import("disk_manager.zig");

var DB_LOOKUP_FILE = "db_lookup.zdb";

pub const ERROR_DB = error{
	WRONG_TABLE_FORMAT,
	DB_EXISTS,
	DB_NOT_EXISTS,
	TABLE_EXISTS,
	LINE_NOT_PRESENT,
};

fn addDbLookup(name: []u8) !void {
	var file = std.fs.cwd().openFile(DB_LOOKUP_FILE, .{ .mode = .read_write }) catch try std.fs.cwd().createFile(DB_LOOKUP_FILE, .{ .read = true });
	defer file.close();
	var handle = f.File{.file = &file, .name = DB_LOOKUP_FILE};

	if (try handle.linePresentInFile(name)) {
		return;
	}

	const stat = try file.stat();
	try file.seekTo(stat.size);
	const writer = file.writer();
	try writer.writeAll(name);
	try writer.writeAll("\n");
}

fn removeDbLookup(name: []u8) !void {
	var file = std.fs.cwd().openFile(DB_LOOKUP_FILE, .{ .mode = .read_only }) catch try std.fs.cwd().createFile(DB_LOOKUP_FILE, .{ .read = true });
	defer file.close();

	var handle = f.File{.file = &file, .name = DB_LOOKUP_FILE};
	try handle.removeLineFromFile(name);
}

pub fn createDb(name: []u8) !void {
	std.fs.cwd().makeDir(name) catch |err| switch (err) {
		error.PathAlreadyExists => {
			try addDbLookup(name);
			return ERROR_DB.DB_EXISTS;
		},
		else => return err,
	};
	try addDbLookup(name);
}

pub fn removeDb(name: []u8) !void {
	std.fs.cwd().deleteDir(name) catch |err| switch (err) {
		error.FileNotFound => {
			try removeDbLookup(name);
			return ERROR_DB.DB_NOT_EXISTS;
		},
		else => return err,
	};
	try removeDbLookup(name);
}

pub fn createTable(name: []u8) !void {
	var it = std.mem.split(u8, name, ".");
	const db_name = it.next();
	const table_name = it.next();
	if (db_name == null or table_name == null ) {
		return ERROR_DB.WRONG_TABLE_FORMAT;
	}
	const db_dir = std.fs.cwd().openDir(db_name.?, .{}) catch |err| switch (err) {
		error.FileNotFound => return ERROR_DB.DB_NOT_EXISTS,
		else => return err,
	};
	const file = db_dir.createFile(table_name.?, .{}) catch |err| switch (err) {
		error.PathAlreadyExists => return ERROR_DB.TABLE_EXISTS,
		else => return err,
	};
	defer file.close();
}

pub fn listDbs() !void {

}
