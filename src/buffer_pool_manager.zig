const std = @import("std");
const dm = @import("disk_manager.zig");
const c = @import("config.zig");
const p = @import("page.zig");
const pg = @import("page_guard.zig");
const Page = p.Page;
const PageGuard = pg.PageGuard;


pub const BufferPoolManager = struct {
	pool_size: usize,
	disk_manager: dm.DiskManager,
	replacer_k: usize = c.LRUK_REPLACER_K,

	fn getPoolSize(self: BufferPoolManager) usize {
		return self.pool_size;
	}

	fn getPages(self: BufferPoolManager) *Page {

	}

	fn newPage(self: *BufferPoolManager, page_id: usize) *Page {

	}

	fn newGuardedPage(self: *BufferPoolManager, page_id: usize) PageGuard {

	}

	fn fetchPage(self: *BufferPoolManager, page_id: usize, access_type: AccessType) *Page {

	}

	fn fetchPageBasic(self: *BufferPoolManager, page_id: usize) PageGuard {

	}

	fn fetchPageRead(self: *BufferPoolManager, page_id: usize) void {

	}

	fn fetchPageWrite(self: *BufferPoolManager, page_id: usize) void {

	}

	fn unpinPage(self: *BufferPoolManager, page_id: usize, access_type: AccessType) bool {

	}

	fn flushPage(self: *BufferPoolManager, page_id: usize) bool {

	}

	fn flushAllPages(self: *BufferPoolManager) void {

	}

	fn deletePage(self: *BufferPoolManager, page_id: usize) bool {

	}

	fn allocatePage(self: *BufferPoolManager) usize {

	}

	fn deallocatePage(self: *BufferPoolManager) void {

	}
};
