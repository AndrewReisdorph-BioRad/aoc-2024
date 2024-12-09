const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const benchmark = @import("utils/benchmark.zig");
const DoublyLinkedList = @import("utils/linked_list.zig").DoublyLinkedList;
const Node = @import("utils/linked_list.zig").Node;

const day = 9;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("../data/day{d}_small.txt", .{day});

const list_size = 21000;

pub fn part_one(reader: *Reader) u64 {
    var sum: u64 = 0;

    const data = reader.get_data();
    var left: usize = 0;
    var right: usize = data.len - 1;
    if (right % 2 == 1) {
        right -= 1;
    }

    var free_space: u32 = 0;
    var blocks_to_move: u32 = 0;
    var left_file_id: u32 = 0;

    var left_position: u32 = 0;

    while (left <= right) {
        const left_is_free_space = (left % 2 == 1) or left == right;
        if (left_is_free_space) {
            const right_file_id = right / 2;
            if (blocks_to_move == 0) {
                blocks_to_move = data[right] - 48;
            }
            if (free_space == 0) {
                free_space = data[left] - 48;
            }
            const blocks_to_move_in_segment = @min(free_space, blocks_to_move);
            for (0..blocks_to_move_in_segment) |_| {
                sum += left_position * right_file_id;
                left_position += 1;
                free_space -= 1;
            }
            blocks_to_move -= blocks_to_move_in_segment;
            if (free_space == 0) {
                left += 1;
            }
            if (blocks_to_move == 0) {
                right -= 2;
            }
        } else {
            const file_blocks = data[left] - 48;
            for (0..file_blocks) |_| {
                sum += left_file_id * left_position;
                left_position += 1;
            }
            left_file_id += 1;
            left += 1;
        }
    }

    return sum;
}

const DiskSegment = struct {
    free: bool,
    length: u8,
    file_id: u16,
};

const DiskSegmentNode = Node(DiskSegment);

fn print_disk(linked_list: *DoublyLinkedList(DiskSegment, list_size)) void {
    var it = linked_list.iterator(false);
    while (it.next()) |node| {
        if (node.payload.free) {
            for (0..node.payload.length) |_| {
                std.debug.print(".", .{});
            }
        } else {
            for (0..node.payload.length) |_| {
                std.debug.print("{d}", .{node.payload.file_id});
            }
        }
    }
    std.debug.print("\n", .{});
}

fn calc_checksum(linked_list: *DoublyLinkedList(DiskSegment, list_size)) u64 {
    var sum: u64 = 0;
    var it = linked_list.iterator(false);
    var block_idx: u64 = 0;
    while (it.next()) |node| {
        if (node.payload.free) {
            block_idx += node.payload.length;
        } else {
            var i: i64 = node.payload.length;
            while (i > 0) : (i -= 1) {
                sum += block_idx * node.payload.file_id;
                block_idx += 1;
            }
        }
    }

    return sum;
}

pub fn part_two(reader: *Reader) u64 {
    const data = reader.get_data();

    // Build the linked list
    var linked_list = DoublyLinkedList(DiskSegment, list_size).init();
    var free_nodes = DoublyLinkedList(*DiskSegmentNode, 10000).init();
    var i: usize = 0;
    for (data) |d| {
        const length = d - 48;
        if (length > 0) {
            const free = i % 2 == 1;
            const node = linked_list.append(DiskSegment{ .free = free, .length = length, .file_id = @as(u16, @intCast(i)) / 2 }) catch @panic("Could not append node");
            if (free) {
                _ = free_nodes.append(node) catch @panic("Could not append node");
            }
        }
        i += 1;
    }

    var backward_iter = linked_list.iterator(true);
    var last_file_id: u16 = 10000;
    while (backward_iter.next()) |candidate_file| {
        if (candidate_file.payload.free or candidate_file.payload.file_id > last_file_id) {
            continue;
        }
        last_file_id = candidate_file.payload.file_id;
        // std.debug.print("Considering: {d} with size: {d}\n", .{ candidate_file.payload.file_id, candidate_file.payload.length });
        var free_node_iter = free_nodes.iterator(false);
        while (free_node_iter.next()) |free_node| {
            // don't consider regions that occur *after* the segment we are moving
            if (free_node.payload.payload.file_id >= candidate_file.payload.file_id) {
                // std.debug.print("Free node file id {d} >= {d}\n", .{ free_node.payload.payload.file_id, candidate_file.payload.file_id });
                break;
            }
            // std.debug.print("  Checking free node: {d} with size: {d}\n", .{ free_node.payload.payload.file_id, free_node.payload.payload.length });

            if (free_node.payload.payload.length >= candidate_file.payload.length) {
                // std.debug.print("  FOUND free node: {d} with size: {d}\n", .{ free_node.payload.payload.file_id, free_node.payload.payload.length });

                const candidate_copy = candidate_file.*;

                candidate_file.payload.free = true;
                if (candidate_file.payload.length == free_node.payload.payload.length) {
                    free_node.payload.payload.free = false;
                    free_node.payload.payload.file_id = candidate_file.payload.file_id;
                    free_nodes.delete(free_node);
                } else {
                    linked_list.insert_before(candidate_copy, free_node.payload);
                    free_node.payload.payload.length -= candidate_file.payload.length;
                }
                // std.debug.print("Used free node: {d}\n", .{free_node.payload.payload.file_id});

                break;
            }
        }
    }

    // print_disk(&linked_list);

    return calc_checksum(&linked_list);
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
    // 00...111...2...333.44.5555.6666.777.888899
    std.debug.print("\n", .{});
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1928);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 6283170117911);
}

test "part 2 small" {
    std.debug.print("\n", .{});
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 2858);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 6307653242596);
}
