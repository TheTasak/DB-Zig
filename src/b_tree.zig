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
                const left_node = try this.createNode(1);
                insert_node = try this.createNode(1);

                var blank = this.findBlankSlot(this.root_node).?;
                this.root_node.keys[blank] = key;
                this.root_node.pointers[blank] = left_node;

                blank = this.findBlankSlot(this.root_node).?;
                this.root_node.pointers[blank] = insert_node;
            } else {
                insert_node = parent_array.items[parent_array.items.len - 1];
            }

            insert_node.insert(key, value) catch |err| {
                std.debug.print("{any} Spliting node {any}\n", .{err, insert_node});
                try this.split_nodes(&parent_array, parent_array.items.len - 1, key, value);
            };
            this.print();
        }

        fn split_nodes(this: *This, parent_array: *std.ArrayList(*Node), parent_level: usize, key: K, value: V) !void {
            const split_node = parent_array.items[parent_level];
            var key_arr: [m+1]?K = split_node.keys ++ [1]?K{null};
            var val_arr: [m+1]?V = split_node.values ++ [1]?V{null};

            split_node.insertSortKeys(&key_arr, &val_arr, key, value, null, null);

            const arr_half: usize = (m + 1) / 2;
            const new_node_left = try this.createNode(split_node.level);
            const new_node_right = try this.createNode(split_node.level);

            for (0..arr_half) |index| {
                try new_node_left.insert(key_arr[index].?, val_arr[index].?);
            }
            for (arr_half..key_arr.len) | index| {
                try new_node_right.insert(key_arr[index].?, val_arr[index].?);
            }

            // TODO: if the root node is full then split the root node, the new nodes make a new level of btree, add the pointers to lower nodes
            const previous_level = parent_level - 1;
            if (previous_level < 0) {

            }

            const insert_key = key_arr[arr_half];
            const modify_pointers_node = parent_array.items[previous_level];
            modify_pointers_node.insertSortKeys(
                &modify_pointers_node.keys,
                &modify_pointers_node.values,
                insert_key.?,
                null,
                new_node_left,
                new_node_right
            );

            // TODO: if higher node is full continue splitting
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

        fn createNode(this: This, level: u8) !*Node {
            const new_node = try this.gpa.create(Node);
            errdefer this.gpa.destroy(new_node);

            new_node.* = Node.init(level);
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

        pub fn insertSortKeys(this: *This, keys: []?K, values: []?V, key: K, value: ?V, node_left: ?*Node, node_right: ?*Node) void {
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

            // Add new pointers if applicable (not leaf node)
            if (node_left) |left| {
                this.pointers[insert_index] = left;
            }
            if (node_right) |right| {
                this.pointers[insert_index+1] = right;
            }
        }

        pub fn insert(this: *This, key: K, value: V) !void {
            if (!this.hasSpace()) return error.OutOfBounds;

            this.insertSortKeys(&this.keys, &this.values, key, value, null, null);
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
