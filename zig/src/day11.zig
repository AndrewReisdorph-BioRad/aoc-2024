const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const benchmark = @import("utils/benchmark.zig");

const day = 11;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("../data/day{d}_small.txt", .{day});

const StoneMap = std.AutoHashMap(u64, std.AutoHashMap(u32, u64));

fn get_stone_count_after_n_blinks(stone_number: u64, blinks: u8, count_map: *StoneMap) u64 {
    // Base Case
    if (blinks == 0) {
        return 1;
    }

    if (count_map.get(stone_number)) |map_for_this_stone| {
        if (map_for_this_stone.get(blinks)) |count| {
            return count;
        }
    } else {
        count_map.put(stone_number, std.AutoHashMap(u32, u64).init(std.heap.page_allocator)) catch @panic("Could not create map");
    }

    var stone_count: u64 = 0;

    if (stone_number == 0) {
        stone_count = get_stone_count_after_n_blinks(1, blinks - 1, count_map);
    } else {
        const stone_number_log10: u32 = @as(u32, @intFromFloat(@floor(std.math.log10(@as(f64, @floatFromInt(stone_number))))));
        if (stone_number_log10 % 2 == 1) {
            const divisor = std.math.pow(u32, 10, @intFromFloat(@ceil(@as(f32, @floatFromInt(stone_number_log10)) / 2.0)));
            const left = stone_number / divisor;
            const right = stone_number % divisor;
            stone_count = get_stone_count_after_n_blinks(left, blinks - 1, count_map) + get_stone_count_after_n_blinks(right, blinks - 1, count_map);
        } else {
            stone_count = get_stone_count_after_n_blinks(stone_number * 2024, blinks - 1, count_map);
        }
    }

    count_map.getPtr(stone_number).?.put(blinks, stone_count) catch @panic("Could not create map");

    return stone_count;
}

pub fn part_one(reader: *Reader) u64 {
    var sum: u64 = 0;

    var map = StoneMap.init(std.heap.page_allocator);
    while (reader.next_int(u64, false)) |stone_number| {
        _ = reader.next_char();
        sum += get_stone_count_after_n_blinks(stone_number, 25, &map);
    }

    var map_iter = map.iterator();
    while (map_iter.next()) |entry| {
        entry.value_ptr.deinit();
    }
    map.deinit();

    return sum;
}

pub fn part_two(reader: *Reader) u64 {
    var sum: u64 = 0;

    var map = StoneMap.init(std.heap.page_allocator);
    while (reader.next_int(u64, false)) |stone_number| {
        _ = reader.next_char();
        sum += get_stone_count_after_n_blinks(stone_number, 75, &map);
    }

    var map_iter = map.iterator();
    var max: u64 = 0;
    while (map_iter.next()) |entry| {
        entry.value_ptr.deinit();
        max = @max(max, entry.key_ptr.*);
    }
    map.deinit();

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
