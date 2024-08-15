const std = @import("std");
const c = @import("config.zig");

pub const DiskManager = struct{
	file_name: []const u8,
	file: ?std.fs.File = null,
	flushes: u8 = 0,
	writes: u8 = 0,

	pub fn init(self: *DiskManager) !void {
		self.file = std.fs.cwd().openFile(self.file_name, .{ .mode = .read_write, .lock = std.fs.File.Lock.shared }) catch try std.fs.cwd().createFile(self.file_name, .{ .read = true, .lock = std.fs.File.Lock.shared });
	}

	pub fn deinit(self: *DiskManager) !void {
		defer self.file.?.close();
	}

	pub fn writePage(self: *DiskManager, page_id: usize, page_data: *[c.PAGE_SIZE] u8) !void {
		const offset: usize = page_id * c.PAGE_SIZE;
		try self.file.?.seekTo(offset);
		const write_count = try self.file.?.write(page_data);
		_ = write_count;
		self.writes += 1;
	}

	pub fn readPage(self: *DiskManager, page_id: usize, page_out: *[c.PAGE_SIZE] u8) !void {
		const offset: usize = page_id * c.PAGE_SIZE;
		const file_size = try self.getFileSize();
		if (offset > file_size) {
			return;
		} else {
			try self.file.?.seekTo(offset);
			const read_count = try self.file.?.read(page_out);
			_ = read_count;
// 			if (read_count < c.PAGE_SIZE) {
// 				@memset(page_out, 0);
// 			}
		}
	}

	fn getFileSize(self: DiskManager) !u64 {
		const stat = self.file.?.stat() catch return 0;
		return stat.size;
	}

};
