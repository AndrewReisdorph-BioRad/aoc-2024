pub fn Node(payload: type) type {
    return struct {
        const Self = @This();
        previous: ?*Self,
        next: ?*Self,
        payload: payload,
        valid: bool,
    };
}

pub fn DoublyLinkedList(payload: type, length: comptime_int) type {
    return struct {
        const Self = @This();
        nodes: [length]Node(payload),
        length: u32,
        head: ?*Node(payload),
        tail: ?*Node(payload),

        pub fn init() Self {
            var new = Self{ .nodes = undefined, .length = 0, .head = null, .tail = null };
            for (0..new.nodes.len) |i| {
                new.nodes[i].valid = false;
            }
            return new;
        }

        pub fn append(self: *Self, node_payload: payload) !*Node(payload) {
            const new_node_idx = self.find_free_node_idx() catch @panic("No free nodes");

            self.nodes[new_node_idx] = Node(payload){ .payload = node_payload, .previous = null, .next = null, .valid = true };
            const node = &self.nodes[new_node_idx];

            if (self.tail) |tail| {
                // Make the current tail point to this new node
                node.previous = tail;
                tail.next = node;
            }

            self.tail = node;

            if (self.head == null) {
                self.head = node;
            }

            self.length += 1;
            return node;
        }

        pub fn delete(self: *Self, node: *Node(payload)) void {
            const is_tail = node == self.tail;
            const is_head = node == self.head;
            if (is_head) {
                self.head = node.next;
            }
            if (node.previous) |previous| {
                previous.next = node.next;
                if (is_tail) {
                    self.tail = previous;
                }
            }
            if (node.next) |next| {
                next.previous = node.previous;
            }
            node.valid = false;
        }

        pub fn insert_before(self: *Self, node_to_insert: Node(payload), insert_before_node: *Node(payload)) void {
            // insert D before B
            //      D
            //      v       =>
            // A -> B -> C     A -> D -> B -> C

            const free_idx = self.find_free_node_idx() catch @panic("Could not insert node");
            self.nodes[free_idx] = node_to_insert;
            var node_D = &self.nodes[free_idx];
            node_D.next = null;
            node_D.previous = null;
            const node_A = insert_before_node.previous;
            var node_B = insert_before_node;

            if (node_A) |a| {
                a.next = node_D;
                node_D.previous = a;
            }

            node_D.next = node_B;
            node_B.previous = node_D;
        }

        pub fn find_free_node_idx(self: *Self) !usize {
            for (self.length..self.nodes.len) |i| {
                if (self.nodes[i].valid == false) {
                    return i;
                }
            }
            return error.noFreeNodes;
        }

        pub fn iterator(self: *Self, reverse: bool) DoublyLinkedListIterator(payload) {
            if (reverse) {
                return DoublyLinkedListIterator(payload).init(self.tail.?, reverse);
            }
            return DoublyLinkedListIterator(payload).init(self.head.?, reverse);
        }
    };
}

fn DoublyLinkedListIterator(payload: type) type {
    return struct {
        const Self = @This();
        current: *Node(payload),
        reverse: bool,
        done: bool,

        pub fn init(start_node: *Node(payload), reverse: bool) Self {
            return Self{ .reverse = reverse, .current = start_node, .done = false };
        }

        pub fn next(self: *Self) ?*Node(payload) {
            if (self.done) {
                return null;
            }

            if (self.reverse) {
                if (self.current.previous == null) {
                    self.done = true;
                    return self.current;
                }
                self.current = self.current.previous.?;
                return self.current.next;
            } else {
                if (self.current.next == null) {
                    self.done = true;
                    return self.current;
                }

                self.current = self.current.next.?;
                return self.current.previous;
            }
        }
    };
}
