const std = @import("std");

const ERROR_FILE = error{
	LINE_NOT_PRESENT,
};

pub const File = struct {
	name: []const u8,
	file: *std.fs.File,

	pub fn linePresentInFile(self: *File, name: []u8) !bool {
		var buf: [512]u8 = undefined;
		var buf_reader = std.io.bufferedReader(self.file.reader());

		while(try buf_reader.reader().readUntilDelimiterOrEof(&buf, '\n')) |line| {
			if (std.mem.eql(u8, name, line)) {
				return true;
			}
		}
		return false;
	}

	pub fn linePositionInFile(self: *File, name: []u8) !u64 {
		var buf: [512]u8 = undefined;
		var buf_reader = std.io.bufferedReader(self.file.reader());
		var position: u64 = 0;

		while(try buf_reader.reader().readUntilDelimiterOrEof(&buf, '\n')) |line| {
			if (std.mem.eql(u8, name, line)) {
				return position;
			}
			position += line.len + 1;
		}
		return ERROR_FILE.LINE_NOT_PRESENT;
	}

	fn goToPreviousLine(self: *File) !void {
		var count: usize = 0;

		try self.file.seekBy(-1);
		while (try self.file.reader().readByte() != '\n') {
			count += 1;
			try self.file.seekBy(-@as(i16, @intCast(count))-1);
		}
		try self.file.seekBy(1);
		return;
	}

	pub fn removeLineFromFile(self: *File, name: []u8) !void {
		var file_write = try std.fs.cwd().openFile(self.name, .{ .mode = .read_write });
		defer file_write.close();

		var buf_reader = std.io.bufferedReader(self.file.reader());
		var buf: [512]u8 = undefined;

		const pos = try self.linePositionInFile(name);
		try file_write.seekTo(pos);
		try self.file.seekTo(pos);
		_ = try self.file.reader().readUntilDelimiterOrEof(&buf, '\n');

		while (try buf_reader.reader().readUntilDelimiterOrEof(&buf, '\n')) |line| {
			try file_write.writer().writeAll(line);
			try file_write.writer().writeByte('\n');
		}
		try file_write.setEndPos(try file_write.getPos());
	}
};
