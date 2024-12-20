const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const SeekFrom = @import("utils/reader.zig").SeekFrom;
const Stack = @import("utils/stack.zig").Stack;
const benchmark = @import("utils/benchmark.zig");

const day = 19;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});

const Color = enum(u3) {
    const Self = @This();
    black = 0,
    green = 1,
    red = 2,
    white = 3,
    blue = 4,
    pub fn from_char(char: u8) Self {
        return @enumFromInt(1 + ((char & 0b0001_0000) >> 3) + (char & 1) - ((char & 0b0000_0010) >> 1));
    }
};

const Node = struct {
    const Self = @This();
    terminal: bool = false,
    parent: ?*Node = null,
    children: [5]?*Node = .{ null, null, null, null, null },

    pub fn get(self: *Self, color: Color) ?*Node {
        return self.children[@intFromEnum(color)];
    }

    pub fn set(self: *Self, color: Color, node: *Node) void {
        self.children[@intFromEnum(color)] = node;
    }
};

fn create_graph(reader: *Reader, allocator: std.mem.Allocator) *Node {
    const root = allocator.create(Node) catch @panic("OOM");
    root.* = Node{};
    var current_node = root;

    while (reader.next_char()) |next_char| {
        if (next_char == '\n') {
            current_node.terminal = true;
            break;
        } else if (next_char == ',') {
            current_node.terminal = true;
            current_node = root;
            _ = reader.next_char();
        } else {
            const color = Color.from_char(next_char);
            if (current_node.get(color)) |child_node| {
                current_node = child_node;
            } else {
                const child_node = allocator.create(Node) catch @panic("OOM");
                child_node.* = Node{ .parent = current_node };
                current_node.set(color, child_node);
                current_node = child_node;
            }
        }
    }

    return root;
}

pub fn part_one(reader: *Reader) u64 {
    var buffer: [45000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    // Create tree
    var root = create_graph(reader, allocator);

    // Eat the next blank line
    _ = reader.next_char();

    var valid_patterns: u64 = 0;

    var a_paths = std.ArrayList(*Node).init(allocator);
    var b_paths = std.ArrayList(*Node).init(allocator);

    var current_paths = &a_paths;
    var new_paths = &b_paths;

    while (true) {
        const next_char = reader.next_char();
        if (next_char == '\n' or next_char == null) {
            // If any current paths are a terminal node than the pattern is possible
            var got_terminal_path = false;
            for (current_paths.items) |path| {
                if (path.terminal) {
                    valid_patterns += 1;
                    got_terminal_path = true;
                    break;
                }
            }
            if (next_char == null) {
                break;
            }
            current_paths.clearRetainingCapacity();
            new_paths.clearRetainingCapacity();
            continue;
        }

        const color = Color.from_char(next_char.?);
        var found_terminal_node = false;
        // Step forward from all current candidate paths
        for (current_paths.items) |path| {
            if (path.terminal) {
                found_terminal_node = true;
            }
            if (path.get(color)) |node| {
                new_paths.append(node) catch unreachable;
            }
        }
        // If all current path's cannot be extended, we can start over from the root
        // *only* if there is at least one terminal node in current_paths
        if (found_terminal_node or current_paths.items.len == 0) {
            if (root.get(color)) |node| {
                new_paths.append(node) catch unreachable;
            }
        }

        if (new_paths.items.len == 0) {
            if (reader.seek_to_next_substr("\n") == null) {
                break;
            }
        }

        // swap lists
        const temp = current_paths;
        current_paths = new_paths;
        new_paths = temp;
        new_paths.clearRetainingCapacity();
    }

    return valid_patterns;
}

pub fn part_two(reader: *Reader) u64 {
    var buffer: [45000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    // Create tree
    var root = create_graph(reader, allocator);

    // Eat the next blank line
    _ = reader.next_char();

    const PathNode = struct {
        inner: *Node,
        multiplicity: u64 = 1,
    };

    var a_paths = std.ArrayList(PathNode).init(allocator);
    var b_paths = std.ArrayList(PathNode).init(allocator);

    var current_paths = &a_paths;
    var new_paths = &b_paths;

    current_paths.append(PathNode{ .inner = root }) catch unreachable;

    var total_combinations: u64 = 0;
    while (true) {
        const next_char = reader.next_char();
        if (next_char == '\n' or next_char == null) {
            // If any current paths are a terminal node than the pattern is possible
            var got_terminal_path = false;
            var combinations_for_this_pattern: u64 = 0;
            for (current_paths.items) |path| {
                if (path.inner.terminal) {
                    total_combinations += path.multiplicity;
                    combinations_for_this_pattern += path.multiplicity;
                    got_terminal_path = true;
                }
            }
            if (next_char == null) {
                break;
            }
            current_paths.clearRetainingCapacity();
            current_paths.append(PathNode{ .inner = root }) catch unreachable;
            new_paths.clearRetainingCapacity();
            continue;
        }

        const color = Color.from_char(next_char.?);
        // Step forward from all current candidate paths.
        var num_root_extensions: u64 = 0;
        for (current_paths.items) |path| {
            if (path.inner.get(color)) |node| {
                new_paths.append(PathNode{ .inner = node, .multiplicity = path.multiplicity }) catch unreachable;
            }
            if (path.inner.terminal) {
                num_root_extensions += path.multiplicity;
            }
        }

        if (num_root_extensions > 0) {
            if (root.get(color)) |node| {
                new_paths.append(PathNode{ .inner = node, .multiplicity = num_root_extensions }) catch unreachable;
            }
        }

        if (new_paths.items.len == 0) {
            if (reader.seek_to_next_substr("\n") == null) {
                break;
            }
        }

        // swap lists
        const temp = current_paths;
        current_paths = new_paths;
        new_paths = temp;
        new_paths.clearRetainingCapacity();
    }

    return total_combinations;
}

pub fn do_benchmark() void {
    benchmark.benchmark(benchmark.BenchmarkOptions{ .name = std.fmt.comptimePrint("Day {d} Part 1", .{day}), .func = struct {
        fn run() void {
            var reader = Reader.from_comptime_path(data_path);
            _ = part_one(&reader);
        }
    }.run, .warm_up_iterations = 5 });
    benchmark.benchmark(benchmark.BenchmarkOptions{ .name = std.fmt.comptimePrint("Day {d} Part 2", .{day}), .func = struct {
        fn run() void {
            var reader = Reader.from_comptime_path(data_path);
            _ = part_two(&reader);
        }
    }.run, .warm_up_iterations = 5 });
}

test "part 1 small" {
    var reader = Reader.init(
        \\r, wr, b, g, bwu, rb, gb, br
        \\
        \\brwrr
        \\bggr
        \\gbbr
        \\rrbgbr
        \\ubwu
        \\bwurrg
        \\brgr
        \\bbrgwb
    );
    const result = part_one(&reader);
    try std.testing.expectEqual(6, result);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    try std.testing.expectEqual(350, result);
}

test "part 2 small" {
    var reader = Reader.init(
        \\r, wr, b, g, bwu, rb, gb, br
        \\
        \\brwrr
        \\bggr
        \\gbbr
        \\rrbgbr
        \\ubwu
        \\bwurrg
        \\brgr
        \\bbrgwb
    );

    const result = part_two(&reader);
    try std.testing.expectEqual(16, result);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    try std.testing.expectEqual(769668867512623, result);
}
