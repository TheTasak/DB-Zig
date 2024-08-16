const std = @import("std");
const c = @import("config.zig");


pub const Page = struct {
	data: ?[]u8 = null,
	page_id: usize = 0,
	pin_count: u16 = 0,
	is_dirty: bool = false,
	allocator: ?std.mem.Allocator = null,

	// TODO: maybe better to pass the allocator in the arguments?
	pub fn init(self: *Page) !void {
		var gpa = std.heap.GeneralPurposeAllocator(.{}){};
		self.allocator = gpa.allocator();
		self.data = try self.allocator.?.alloc(u8, c.PAGE_SIZE);
		@memset(self.data.?[0..self.data.?.len], 0);
	}

	pub fn deinit(self: *Page) void {
		if (self.data) |data| {
			defer self.allocator.?.free(data);
		}
	}

};
