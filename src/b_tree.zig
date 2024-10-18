const std = @import("std");

pub fn BTree(comptime m: comptime_int) type {
    return struct {
        const This = @This();
        const RootNode = BNode(m);

        root_node: *RootNode,
        gpa: std.mem.Allocator,
        max_level: u8,

        pub fn init(gpa: std.mem.Allocator) !This {
            const root = try gpa.create(RootNode);
            errdefer gpa.destroy(root);

            root.* = RootNode.init(0);
            root.keys[0] = 1;
            root.values[0] = 100;
            return This{ .gpa = gpa, .root_node = root, .max_level = 0 };
        }

        pub fn deinit(this: *This) void {
            // TODO: This should destroy all the children recursively
            this.gpa.destroy(this.root_node);
        }

        pub fn findValue(this: This, key: u8) ?u8 {
            return this.findIterate(key, this.root_node);
        }

        // pub fn findLeaf(this: This, key: u8) ?u8 {}

        fn findIterate(this: This, key: u8, current_node: *RootNode) ?u8 {
            const is_leaf_node = current_node.level == this.max_level;

            for (current_node.keys, 0..current_node.keys.len) |n_key, index| {
                if (key == n_key) return current_node.values[index];
                if (key < n_key) {
                    if (!is_leaf_node) {
                        return this.findIterate(key, current_node.pointers[index]);
                    } else {
                        return null;
                    }
                }
            }

            if (key < current_node.keys[m - 1] and !is_leaf_node) {
                return this.findIterate(key, current_node.pointers[m]);
            } else {
                return null;
            }
        }

        pub fn insert(this: *This, key: u8, value: u8) !void {
            const val_exists = this.findValue(key) != null;

            // Probably need to handle multiple of the same keys
            if (val_exists) {
                return;
            }

            _ = value;
        }

        pub fn print(this: This) void {
            std.debug.print("VALUES: {d}\n", .{this.rootNode.getValues()});
        }
    };
}

pub fn BNode(comptime m: comptime_int) type {
    return struct {
        const This = @This();
        const Node = BNode(m);

        prevNode: ?*Node,
        nextNode: ?*Node,
        keys: [m]u8,
        values: [m]u8,
        pointers: [m + 1]*Node,
        level: u8,
        slots: u8,

        pub fn init(level: u8) This {
            return This{
                .level = level,
                .prevNode = undefined,
                .nextNode = undefined,
                .slots = m,
                .values = undefined,
                .keys = undefined,
                .pointers = undefined,
            };
        }

        pub fn getValues(this: This) [m]u8 {
            return this.values;
        }

        pub fn getValue(this: This, n: usize) !u8 {
            if (n >= m) return error.OutOfBounds;
            return this.values[n];
        }
    };
}
