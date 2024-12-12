const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const benchmark = @import("utils/benchmark.zig");

const day = 11;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("../data/day{d}_small.txt", .{day});

fn StoneMap(blinks: comptime_int) type {
    return struct {
        const Self = @This();
        const BlinkLookup = [blinks + 1]u64;
        inner: std.AutoHashMap(u64, BlinkLookup),

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{ .inner = std.AutoHashMap(u64, BlinkLookup).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.inner.deinit();
        }

        pub fn get(self: *Self, key: u64, num_blinks: u32) u64 {
            if (self.inner.get(key)) |entry| {
                return entry[num_blinks];
            }
            return 0;
        }

        pub fn set(self: *Self, key: u64, num_blinks: u32, stone_count: u64) void {
            var result = self.inner.getOrPut(key) catch unreachable;
            if (result.found_existing) {
                result.value_ptr[num_blinks] = stone_count;
            } else {
                result.value_ptr.* = std.mem.zeroes(BlinkLookup);
                result.value_ptr[num_blinks] = stone_count;
            }
        }
    };
}

fn get_stone_count_after_n_blinks(stone_number: u64, blinks: u8, stone_map: anytype) u64 {
    // Base Case
    if (blinks == 0) {
        return 1;
    }

    const lookup = stone_map.get(stone_number, blinks);
    if (lookup > 0) {
        return lookup;
    }

    var stone_count: u64 = 0;
    if (stone_number == 0) {
        stone_count = get_stone_count_after_n_blinks(1, blinks - 1, stone_map);
    } else {
        const stone_number_log10: u32 = @as(u32, @intFromFloat(@floor(std.math.log10(@as(f64, @floatFromInt(stone_number))))));
        if (stone_number_log10 % 2 == 1) {
            const divisor = std.math.pow(u32, 10, @intFromFloat(@ceil(@as(f32, @floatFromInt(stone_number_log10)) / 2.0)));
            const left = stone_number / divisor;
            const right = stone_number % divisor;
            stone_count = get_stone_count_after_n_blinks(left, blinks - 1, stone_map) + get_stone_count_after_n_blinks(right, blinks - 1, stone_map);
        } else {
            stone_count = get_stone_count_after_n_blinks(stone_number * 2024, blinks - 1, stone_map);
        }
    }

    stone_map.set(stone_number, blinks, stone_count);

    return stone_count;
}

pub fn part_one(reader: *Reader) u64 {
    var sum: u64 = 0;

    const blinks = 25;
    var map = StoneMap(blinks).init(std.heap.page_allocator);
    defer map.deinit();

    while (reader.next_int(u64, false)) |stone_number| {
        _ = reader.next_char();
        sum += get_stone_count_after_n_blinks(stone_number, blinks, &map);
    }

    return sum;
}

pub fn part_two(reader: *Reader) u64 {
    var sum: u64 = 0;

    const blinks = 75;
    var map = StoneMap(blinks).init(std.heap.page_allocator);
    defer map.deinit();
    while (reader.next_int(u64, false)) |stone_number| {
        _ = reader.next_char();
        sum += get_stone_count_after_n_blinks(stone_number, blinks, &map);
    }

    return sum;
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
    try std.testing.expect(result == 55312);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 189092);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 224869647102559);
}
