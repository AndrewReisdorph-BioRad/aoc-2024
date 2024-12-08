const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const benchmark = @import("utils/benchmark.zig");

const day = 1;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("../data/day{d}_small.txt", .{day});

const Day1Data = struct {
    left: std.ArrayList(u32),
    right: std.ArrayList(u32),

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.left.deinit();
        self.right.deinit();
    }
};

pub fn get_sorted_data(reader: *Reader) Day1Data {
    var left = std.ArrayList(u32).init(std.heap.page_allocator);
    var right = std.ArrayList(u32).init(std.heap.page_allocator);

    var counter: u32 = 0;

    while (true) {
        const maybe_next = reader.next_u32(true);
        if (maybe_next) |next| {
            if (counter % 2 == 0) {
                left.append(next) catch unreachable;
            } else {
                right.append(next) catch unreachable;
            }
            counter += 1;
        } else {
            break;
        }
    }

    std.mem.sort(u32, left.items, {}, std.sort.asc(u32));
    std.mem.sort(u32, right.items, {}, std.sort.asc(u32));

    return Day1Data{ .left = left, .right = right };
}

pub fn part_one(reader: *Reader) u64 {
    var data = get_sorted_data(reader);
    defer data.deinit();

    var sum: u64 = 0;
    for (0..data.left.items.len) |i| {
        const difference = @as(i64, data.left.items[i]) - @as(i64, data.right.items[i]);
        sum += @as(u64, @abs(difference));
    }

    return sum;
}

pub fn part_two(reader: *Reader) u64 {
    var data = get_sorted_data(reader);
    defer data.deinit();

    var last_similarity_increment: u64 = 0;
    var last_similar: ?u32 = null;
    var similarity: u64 = 0;
    var left_index: u32 = 0;
    var right_index: u32 = 0;
    var count: u64 = 0;

    while (left_index < data.left.items.len and right_index < data.right.items.len) {
        const left_candidate = data.left.items[left_index];
        const right_candidate = data.right.items[right_index];

        if (left_candidate == last_similar and last_similarity_increment > 0) {
            similarity += last_similarity_increment;
        }

        if (right_candidate < left_candidate) {
            right_index += 1;
        } else if (right_candidate == left_candidate) {
            count += 1;
            right_index += 1;
            last_similar = right_candidate;
            last_similarity_increment = 0;
        } else if (right_candidate > left_candidate) {
            if (count > 0) {
                last_similarity_increment = @as(u64, left_candidate) * count;
                similarity += last_similarity_increment;
                count = 0;
            }
            left_index += 1;
        }
    }

    return similarity;
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
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 11);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1258579);
}

test "part 2 small" {
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 31);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 23981443);
}
