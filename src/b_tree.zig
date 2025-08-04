const std = @import("std");

pub fn BTree(comptime K: type, comptime V: type, comptime m: comptime_int) type {
    return struct {
        const This = @This();
        const Node = BNode(K, V, m);
        const SplitNode = BSplitNode(K, V, m);

        root_node: *Node,
        gpa: std.mem.Allocator,
        max_level: u8,

        pub fn init(gpa: std.mem.Allocator) !This {
            const root = try gpa.create(Node);
            errdefer gpa.destroy(root);

            root.* = Node.init();
            return This{ .gpa = gpa, .root_node = root, .max_level = 0 };
        }

        pub fn deinit(this: *This) void {
            this.deinitRecursive(this.root_node);
            this.gpa.destroy(this.root_node);
        }

        fn deinitRecursive(this: *This, node: *Node) void {
            for (node.pointers, 0..node.pointers.len) |iter_node, _| {
                const delete_node = iter_node orelse break;
                this.deinitRecursive(delete_node);
                this.gpa.destroy(delete_node);
            }
        }

        pub fn findValue(this: This, key: K) ?V {
            return this.findIterate(key, this.root_node);
        }

        pub fn insert(this: *This, key: K, value: V) !void {
            std.debug.print("Inserting key: {d} value: {d}\n", .{key, value});
            var parent_array = std.ArrayList(*Node).init(this.gpa);
            defer parent_array.deinit();

            var found = this.findIterateNode(key, this.root_node);
            try parent_array.append(this.root_node);

            while (found != null) {
                try parent_array.append(found.?);
                found = this.findIterateNode(key, found.?);
            }
            var insert_node: *Node = undefined;

            if (parent_array.items.len == 1) {
                const left_node = try this.createNode();
                insert_node = try this.createNode();

                var blank = this.findBlankSlot(this.root_node).?;
                this.root_node.keys[blank] = key;
                this.root_node.pointers[blank] = left_node;

                blank = this.findBlankSlot(this.root_node).?;
                this.root_node.pointers[blank] = insert_node;
                this.root_node.slots -= 1;
            } else {
                insert_node = parent_array.items[parent_array.items.len - 1];
            }

            insert_node.insert(key, value) catch |err| {
                std.debug.print("{any} Spliting node {any}\n", .{err, insert_node});
                try this.split_nodes(&parent_array, parent_array.items.len - 1, key, value, null);
            };
            this.print();
        }

        fn split_nodes(this: *This, parent_array: *std.ArrayList(*Node), parent_level: usize, key: K, value: ?V, _: ?SplitNode) !void {
            const split_node = parent_array.items[parent_level];
            var key_arr: [m+1]?K = split_node.keys ++ [1]?K{null};
            var val_arr: [m+1]?V = split_node.values ++ [1]?V{null};

            _ = split_node.insertSortKeys(&key_arr, &val_arr, key, value);

            std.debug.print("KEYS FOR SPLITING: {any}\n", .{key_arr});
            std.debug.print("VALUES FOR SPLITING: {any}\n", .{val_arr});

            // TODO: based on split node insert correct pointers on next split (if present)

            const arr_half: usize = (m + 1) / 2;
            const new_node_left = try this.createNode();
            const new_node_right = try this.createNode();

            for (0..arr_half) |index| {
                new_node_left.keys[index] = key_arr[index].?;
                if (val_arr[index]) |val| {
                    new_node_left.values[index] = val;
                }
                new_node_left.slots -= 1;
            }
            for (arr_half..key_arr.len, 0..) | index, insert_i| {
                new_node_right.keys[insert_i] = key_arr[index].?;
                if (val_arr[index]) |val| {
                    new_node_right.values[insert_i] = val;
                }
                new_node_right.slots -= 1;
            }

            std.debug.print("Node left: {any}\n", .{new_node_left});
            std.debug.print("Node right: {any}\n", .{new_node_right});

            // TODO: if the root node is full then split the root node, the new nodes make a new level of btree, add the pointers to lower nodes
            if (parent_level > 0) {
                const previous_level = parent_level - 1;
                const insert_key = key_arr[arr_half];
                const modify_pointers_node = parent_array.items[previous_level];

                // number of slots for values is m, whereas for pointers it's m+1
                if (modify_pointers_node.slots == 0) {
                    std.debug.print("GOING BACK THE TREE CURRENT NODE \n{any}\n", .{parent_array.items[parent_level - 1]});
                    const split_node_pointer = SplitNode.init(new_node_left, new_node_right);
                    try this.split_nodes(parent_array, parent_level - 1, key_arr[arr_half].?, null, split_node_pointer);
                }

                const insert_index = modify_pointers_node.insertSortKeys(
                    &modify_pointers_node.keys,
                    &modify_pointers_node.values,
                    insert_key.?,
                    null
                );
                modify_pointers_node.slots -= 1;
                modify_pointers_node.pointers[insert_index] = new_node_left;
                modify_pointers_node.pointers[insert_index+1] = new_node_right;
            }

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

        fn createNode(this: This) !*Node {
            const new_node = try this.gpa.create(Node);
            errdefer this.gpa.destroy(new_node);

            new_node.* = Node.init();
            return new_node;
        }

        fn findIterateNode(_: This, key: K, current_node: *Node) ?*Node {
            for (current_node.keys, 0..current_node.keys.len) |n_key, index| {
                if (n_key == null and index == 0) {
                    return null;
                } else if (n_key == null and index != 0) {
                    return current_node.pointers[index];
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
            std.debug.print("SLOTS {any}\n", .{this.root_node.slots});
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
        slots: u8,

        pub fn init() This {
            return This{
                .prev_node = null,
                .next_node = null,
                .slots = m,
                .values = [_]?V{null} ** m,
                .keys = [_]?K{null} ** m,
                .pointers = [_]?*Node{null} ** (m + 1),
            };
        }

        pub fn insertSortKeys(_: *This, keys: []?K, values: []?V, key: K, value: ?V) usize {
            var key_arr = keys;
            var val_arr = values;
            // Find the correct place for inserting in regards to key sorting
            var insert_index: usize = undefined;
            for (key_arr, 0..key_arr.len) |n_key, index| {
                if (n_key == null or key < n_key.?) {
                    insert_index = index;
                    break;
                }
            }

            // Shift all values to the right of insertion place
            for (0..key_arr.len-insert_index-1) |index| {
                const change_index = key_arr.len-index-1;
                key_arr[change_index] = key_arr[change_index-1];
                val_arr[change_index] = val_arr[change_index-1];
            }
            key_arr[insert_index] = key;
            val_arr[insert_index] = value;

            return insert_index;
        }

        pub fn insert(this: *This, key: K, value: V) !void {
            if (!this.hasSpace()) return error.OutOfBounds;

            _ = this.insertSortKeys(&this.keys, &this.values, key, value);
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


pub fn BSplitNode(comptime K: type, comptime V: type, comptime m: comptime_int) type {
    return struct {
        const This = @This();
        const Node = BNode(K, V, m);

        left_node: *Node,
        right_node: *Node,

        pub fn init(left: *Node, right: *Node) This {
            return This{ .left_node = left, .right_node = right };
        }
    };
}