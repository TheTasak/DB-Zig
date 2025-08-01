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
            const is_leaf_node = current_node.level == this.max_level and current_node.level != 0;

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
            var parent_array = std.ArrayList(*Node).init(this.gpa);
            defer parent_array.deinit();

            var found = this.findIterateNode(key, this.root_node);
            try parent_array.append(this.root_node);

            while (found != null) {
                try parent_array.append(found.?);
                found = this.findIterateNode(key, found.?);
            }
            var node: *Node = undefined;

            if (parent_array.items.len == 1) {
                node = try this.createNode(1);
                const blank = this.findBlankSlot(this.root_node).?;
                // there can be no blank slots in root, then go down and search for new
                this.root_node.keys[blank] = key;
                this.root_node.pointers[blank] = node;
            } else {
                node = parent_array.items[parent_array.items.len - 1];
            }
            try node.insert(key, value);
            this.print();
        }

        fn findBlankSlot(_: This, current_node: *Node) ?usize {
           for (current_node.keys, 0..current_node.keys.len) |n_key, index| {
              if (n_key == null) {
                  return index;
              }
           }
           return null;
        }

        fn createNode(this: This, level: comptime_int) !*Node {
            const new_node = try this.gpa.create(Node);
            errdefer this.gpa.destroy(new_node);

            new_node.* = Node.init(level);
            return new_node;
        }

        fn findIterateNode(_: This, key: K, current_node: *Node) ?*Node {
            for (current_node.keys, 0..current_node.keys.len) |n_key, index| {
                if (n_key == null) {
                    return null;
                }

                if (key < n_key.?) {
                    return current_node.pointers[index];
                }
            }
            return current_node.pointers[current_node.pointers.len - 1];
        }

        pub fn print(this: This) void {
            std.debug.print("POINTERS {any}\n", .{this.root_node.pointers});
            std.debug.print("KEYS {any}\n", .{this.root_node.keys});
            std.debug.print("VALUES {any}\n", .{this.root_node.values});
            std.debug.print("\n", .{});
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

            // Find the correct place for inserting in regards to key sorting
            var insert_index: usize = undefined;
            for (this.keys, 0..this.keys.len) |n_key, index| {
                if (n_key == null or key < n_key.?) {
                    insert_index = index;
                    break;
                }
            }

            // Shift all values to the right of insertion place
            for (0..this.keys.len-insert_index-1) |index| {
                const change_index = this.keys.len-index-1;
                this.keys[change_index] = this.keys[change_index-1];
                this.values[change_index] = this.values[change_index-1];
            }

            // Add new value
            this.keys[insert_index] = key;
            this.values[insert_index] = value;
            this.slots -= 1;
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
