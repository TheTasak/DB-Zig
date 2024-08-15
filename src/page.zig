const std = @import("std");
const c = @import("config.zig");


pub const Page = struct {
	data: *[c.PAGE_SIZE] u8,
	page_id: usize,
	ping_count: u16 = 0,
	is_dirty: bool = false,
	allocator: ?std.mem.Allocator = null,

	fn init(self: *Page) void {
		var gpa = std.heap.GeneralPurposeAllocator(.{}){};
		self.allocator = gpa.allocator();
		self.data = try self.allocator.?.alloc(u8, c.PAGE_SIZE);
	}

	fn deinit(self: *Page) void {
		defer self.allocator.?.free(self.data);
	}
};
