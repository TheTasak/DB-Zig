const std = @import("std");
const dbms = @import("dbms.zig");
const dm = @import("disk_manager.zig");
const c = @import("config.zig");
const p = @import("page.zig");
const btree = @import("b_tree.zig");
const ERROR_ARGS = error{
    WRONG_ARGUMENT,
};

const ARGS_PERMIT = enum {
    create_db,
    remove_db,
    create_table,
    execute_query,
    list_dbs,
};

fn argsPos(compare: [:0]u8) ?usize {
    inline for (0.., @typeInfo(ARGS_PERMIT).Enum.fields) |index, field| {
        if (std.mem.eql(u8, field.name, compare)) {
            return index;
        }
    }
    return null;
}

const Args = struct {
    args: [][:0]u8,

    pub fn handleArguments(self: Args) !void {
        var command_index: ?usize = null;

        for (0.., self.args) |index, arg| {
            const enum_pos: ?usize = argsPos(arg[1..]);
            const is_command = arg[0] == '-' and enum_pos != null and command_index == null;
            const is_arg = arg[0] != '-' and command_index != null;

            if (is_command) {
                command_index = enum_pos.?;
                std.debug.print("Arg index: {d}\n", .{index});
            } else if (is_arg) {
                defer command_index = null;

                if (command_index) |pos| {
                    const arg_command: ARGS_PERMIT = @enumFromInt(pos);
                    switch (arg_command) {
                        ARGS_PERMIT.create_db => try dbms.createDb(arg),
                        ARGS_PERMIT.create_table => try dbms.createTable(arg),
                        ARGS_PERMIT.execute_query => std.debug.print("{d} {s}\n", .{ pos, arg }),
                        ARGS_PERMIT.remove_db => try dbms.removeDb(arg),
                        ARGS_PERMIT.list_dbs => try dbms.listDbs(),
                    }
                }
            } else {
                return ERROR_ARGS.WRONG_ARGUMENT;
            }
        }
    }

    pub fn print(self: Args) void {
        std.debug.print("\n", .{});
        for (self.args) |arg| {
            std.debug.print("{s}\n", .{arg});
        }
    }
};

fn threadPrint(thread_num: usize) void {
    for (0..10) |index| {
        std.debug.print("THREAD {d}: {d}\n", .{ thread_num, index });
    }
}

fn tryDiskManager() void {
    const file_name = "test.zdb";
    var disk_manager = dm.DiskManager{ .file_name = file_name };
    try disk_manager.init();

    var buffer: [c.PAGE_SIZE]u8 = [_]u8{0} ** c.PAGE_SIZE;
    var data: [c.PAGE_SIZE]u8 = [_]u8{0} ** c.PAGE_SIZE;

    const test_string = "Many more where it came from.";
    @memcpy(data[0..test_string.len], test_string);

    // try disk_manager.readPage(0, &buffer);
    // try disk_manager.writePage(2, &data);
    try disk_manager.readPage(0, &buffer);
    std.debug.print("DATA: {s}", .{buffer});
    // var page = p.Page{};
    // try page.init();
    // std.debug.print("TEST: {any}", .{page.data.?});
    // defer page.deinit();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // const args = try std.process.argsAlloc(allocator);
    // defer std.process.argsFree(allocator, args);
    //
    // const arg = Args{.args = args[1..]};
    // arg.print();
    // arg.handleArguments() catch |err| switch (err) {
    // else => std.debug.print("{any}\n", .{err}),
    // };
    var b_tree = try btree.BTree(u16, u16, 3).init(allocator);
    defer b_tree.deinit();
    // const value = b_tree.find(2);
    // std.debug.print("HELLO: {any}\n", .{value});
    try b_tree.insert(3, 100);
    try b_tree.insert(10, 300);
    try b_tree.insert(1, 200);
    try b_tree.insert(2, 900);
    try b_tree.insert(4, 600);
    try b_tree.insert(12, 600);
    try b_tree.insert(14, 600);
}
