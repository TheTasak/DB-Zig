const std = @import("std");

pub fn BTree(comptime K: type, comptime V: type, comptime m: comptime_int) type {
    return struct {
        const This = @This();
        const Node = BNode(K, V, m);

        root_node: *Node,
        gpa: std.mem.Allocator,
        max_level: u8,

        pub fn init(gpa: std.mem.Allocator) !This {
            const root = try gpa.create(Node);
            errdefer gpa.destroy(root);

            root.* = Node.init(0);
            return This{ .gpa = gpa, .root_node = root, .max_level = 0 };
        }

        pub fn deinit(this: *This) void {
            // TODO: This should destroy all the children recursively
            this.gpa.destroy(this.root_node);
        }

        pub fn findValue(this: This, key: K) ?V {
            return this.findIterate(key, this.root_node);
        }

        fn findIterate(this: This, key: K, current_node: *Node) ?V {
            const is_leaf_node = current_node.level == this.max_level;

            for (current_node.keys, 0..current_node.keys.len) |n_key, index| {
                if (n_key == null) return null;

                if (key == n_key) return current_node.values[index];
                if (key < n_key.? and !is_leaf_node) {
                    return this.findIterate(key, current_node.pointers[index].?);
                } else {
                    return null;
                }
            }

            if (current_node.keys[m - 1]) |n_key| {
                if (key < n_key and !is_leaf_node) {
                    return this.findIterate(key, current_node.pointers[m].?);
                } else {
                    return null;
                }
            }

            return null;
        }

        pub fn insert(this: *This, key: K, value: V) !void {
            const val_exists = this.findValue(key) != null;

            // Probably need to handle multiple of the same keys
            if (val_exists) {
                return;
            }

            var parent_array = std.ArrayList(*Node).init(this.gpa);
            defer parent_array.deinit();

            var found = this.findIterateNode(key, this.root_node);
            try parent_array.append(this.root_node);

            while (found != null) {
                try parent_array.append(found.?);
                found = this.findIterateNode(key, found.?);
            }
            const firstItem = parent_array.items[0];

            for (0..parent_array.items.len) |index| {
                var current_item = parent_array.items[parent_array.items.len - index - 1];
                if (!current_item.hasSpace()) {
                    // TODO: Need to break up parent node recursively
                    break;
                }

                try current_item.insert(key, value);
            }
            std.debug.print("{any} {d}\n", .{ firstItem, value });
        }

        fn findIterateNode(this: This, key: K, current_node: *Node) ?*Node {
            const is_leaf_node = current_node.level == this.max_level;

            _ = key;
            if (is_leaf_node) return null;
            if (!current_node.hasSpace()) return null;

            return null;
        }

        pub fn print(this: This) void {
            std.debug.print("VALUES: {d}\n", .{this.rootNode.getValues()});
        }
    };
}

pub fn BNode(comptime K: type, comptime V: type, comptime m: comptime_int) type {
    return struct {
        const This = @This();
        const Node = BNode(K, V, m);

        prev_node: ?*Node,
        next_node: ?*Node,
        keys: [m]?K,
        values: [m]?V,
        pointers: [m + 1]?*Node,
        level: u8,
        slots: u8,

        pub fn init(level: u8) This {
            return This{
                .level = level,
                .prev_node = null,
                .next_node = null,
                .slots = m,
                .values = [_]?V{null} ** m,
                .keys = [_]?K{null} ** m,
                .pointers = [_]?*Node{null} ** (m + 1),
            };
        }

        pub fn insert(this: *This, key: K, value: V) !void {
            if (!this.hasSpace()) return error.OutOfBounds;
            this.keys[m - this.slots] = key;
            this.values[m - this.slots] = value;
            this.slots -= 1;
            // TODO: Sort keys, values and pointers based on key
        }

        pub fn upperBound(this: This) K {
            return this.keys[m - this.slots];
        }

        pub fn lowerBound(this: This) K {
            return this.keys[0];
        }

        pub fn hasSpace(this: This) bool {
            return this.slots > 0;
        }

        pub fn getValues(this: This) [m]V {
            return this.values;
        }

        pub fn getValue(this: This, n: usize) !V {
            if (n >= m) return error.OutOfBounds;
            return this.values[n];
        }
    };
}
