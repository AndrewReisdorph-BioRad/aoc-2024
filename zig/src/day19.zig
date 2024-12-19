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

pub fn part_one(reader: *Reader) u64 {
    // var buffer: [32000]u8 = undefined;
    // var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // const allocator = fba.allocator();
    const allocator = std.heap.page_allocator;

    // Create tree
    var root = Node{};
    var current_node = &root;

    while (reader.next_char()) |next_char| {
        if (next_char == '\n') {
            current_node.terminal = true;
            break;
        } else if (next_char == ',') {
            current_node.terminal = true;
            current_node = &root;
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

    // Eat the next blank line
    _ = reader.next_char();

    var valid_patterns: u64 = 0;
    current_node = &root;

    // const NodeWithOffset = struct { node: *Node, offset: u64 };

    // var path_stack = Stack(NodeWithOffset, 80).init();

    var a_paths = std.ArrayList(*Node).init(allocator);
    var b_paths = std.ArrayList(*Node).init(allocator);

    var current_paths = &a_paths;
    var new_paths = &b_paths;

    var current_path_length: u32 = 0;

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
            if (got_terminal_path) {
                std.debug.print("Pattern is possible!\n======================\n", .{});
            } else {
                std.debug.print("Pattern not possible\n======================\n", .{});
            }
            if (next_char == null) {
                break;
            }
            current_path_length = 0;
            current_paths.clearRetainingCapacity();
            new_paths.clearRetainingCapacity();
            continue;
        }

        const color = Color.from_char(next_char.?);
        std.debug.print("{c} ", .{next_char.?});
        var found_terminal_node = false;
        // Step forward from all current candidate paths
        for (current_paths.items) |path| {
            if (path.terminal) {
                found_terminal_node = true;
            }
            if (path.get(color)) |node| {
                std.debug.print(" found path ", .{});
                new_paths.append(node) catch unreachable;
            }
        }
        // If all current path's cannot be extended, we can start over from the root
        // *only* if there is at least one terminal node in current_paths
        if (found_terminal_node or current_path_length == 0) {
            if (root.get(color)) |node| {
                std.debug.print(" Found new path from root. ", .{});
                new_paths.append(node) catch unreachable;
            }
        }

        if (new_paths.items.len == 0) {
            if (reader.seek_to_next_substr("\n") == null) {
                break;
            }
        } else {
            current_path_length += 1;
        }

        std.debug.print("\n", .{});

        const temp = current_paths;
        current_paths = new_paths;
        new_paths = temp;
        new_paths.clearRetainingCapacity();
    }

    return valid_patterns;
}

pub fn part_one(reader: *Reader) u64 {
    // var buffer: [32000]u8 = undefined;
    // var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // const allocator = fba.allocator();
    const allocator = std.heap.page_allocator;

    // Create tree
    var root = Node{};
    var current_node = &root;

    while (reader.next_char()) |next_char| {
        if (next_char == '\n') {
            current_node.terminal = true;
            break;
        } else if (next_char == ',') {
            current_node.terminal = true;
            current_node = &root;
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

    // Eat the next blank line
    _ = reader.next_char();

    var valid_patterns: u64 = 0;
    current_node = &root;

    // const NodeWithOffset = struct { node: *Node, offset: u64 };

    // var path_stack = Stack(NodeWithOffset, 80).init();

    var a_paths = std.ArrayList(*Node).init(allocator);
    var b_paths = std.ArrayList(*Node).init(allocator);

    var current_paths = &a_paths;
    var new_paths = &b_paths;

    var current_path_length: u32 = 0;
    var combinations_for_this_pattern: u64 = 0;
    var total_combinations: u64 = 0;
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
            if (got_terminal_path) {
                total_combinations += combinations_for_this_pattern;
                std.debug.print("Pattern is possible!\n======================\n", .{});
            } else {
                std.debug.print("Pattern not possible\n======================\n", .{});
            }
            if (next_char == null) {
                break;
            }
            current_path_length = 0;
            current_paths.clearRetainingCapacity();
            new_paths.clearRetainingCapacity();
            continue;
        }

        const color = Color.from_char(next_char.?);
        std.debug.print("{c} ", .{next_char.?});
        var found_terminal_node = false;
        // Step forward from all current candidate paths
        for (current_paths.items) |path| {
            if (path.terminal) {
                found_terminal_node = true;
            }
            if (path.get(color)) |node| {
                std.debug.print(" found path ", .{});
                new_paths.append(node) catch unreachable;
            }
        }
        // If all current path's cannot be extended, we can start over from the root
        // *only* if there is at least one terminal node in current_paths
        if (found_terminal_node or current_path_length == 0) {
            if (root.get(color)) |node| {
                std.debug.print(" Found new path from root. ", .{});
                new_paths.append(node) catch unreachable;
            }
        }

        if (new_paths.items.len == 0) {
            if (reader.seek_to_next_substr("\n") == null) {
                break;
            }
        } else {
            current_path_length += 1;
        }

        std.debug.print("\n", .{});

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
    // var reader = Reader.init(
    //     \\r, w, wr, b, g, bwu, rb, gb, br, rb, ru
    //     \\
    //     \\bwru
    // );
    std.debug.print("\n", .{});
    const result = part_one(&reader);
    try std.testing.expectEqual(6, result);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    try std.testing.expectEqual(1, result);
}

test "part 2 small" {
    var reader = Reader.init(
        \\r, wr, b, g, bwu, rb, gb, br
        \\
        \\brwrr
        \\bggr
        // \\gbbr
        // \\rrbgbr
        // \\ubwu
        // \\bwurrg
        // \\brgr
        // \\bbrgwb
    );
    std.debug.print("\n", .{});

    const result = part_two(&reader);
    try std.testing.expectEqual(1, result);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    try std.testing.expectEqual(1, result);
}

// while (true) {
//     const next_char = reader.next_char();

//     var invalid = false;

//     // Check if at the end of the pattern
//     if (next_char == null or next_char == '\n') {
//         if (current_node.terminal) {
//             valid_patterns += 1;
//             path_stack.clear();
//             current_node = &root;
//             std.debug.print(" Pattern is valid!\n", .{});
//             std.debug.print("------------------\n", .{});
//             if (next_char == null) {
//                 break;
//             }
//             continue;
//         } else {
//             invalid = true;
//         }
//     }

//     if (!invalid) {
//         const color = Color.from_char(next_char.?);
//         std.debug.print("{any}  ", .{color});

//         if (current_node.get(color) == null) {
//             if (current_node.terminal) {
//                 std.debug.print("Terminal node has no path to next color. Resetting to root. ", .{});
//                 current_node = &root;
//             }
//         }

//         if (current_node.get(color)) |node| {
//             current_node = node;
//             std.debug.print("Color is in current path. ", .{});
//             if (node.terminal) {
//                 path_stack.push(NodeWithOffset{ .node = node, .offset = reader.tell() }) catch @panic("Stack OOM");
//             }
//         } else {
//             invalid = true;
//         }
//     }

//     if (invalid) {
//         if (path_stack.pop()) |path| {
//             std.debug.print("Current path invalid Seeking back: {d}", .{(reader.tell() - path.offset) - 1});
//             reader.seek(SeekFrom.Start, @as(i32, @intCast(path.offset)));
//             current_node = &root;
//         } else {
//             // Skip to the next pattern
//             std.debug.print(" Pattern not possible!\n", .{});
//             std.debug.print("------------------\n", .{});
//             if (reader.seek_to_next_substr("\n") == null) {
//                 break;
//             }
//             _ = reader.next_char();
//             current_node = &root;
//         }
//     }
