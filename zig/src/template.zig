const std = @import("std");
const Reader = @import("reader.zig").Reader;
const benchmark = @import("benchmark.zig");

const day = 0;
const data_path = std.fmt.comptimePrint("./data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("./data/day{d}_small.txt", .{day});

pub fn part_one(reader: *Reader) u64 {
    var sum: u64 = 0;

    // Remove this vvv
    if (reader.data.len > 0) {
        sum += 1;
    }
    // Remove this ^^^

    return sum;
}

pub fn part_two(reader: *Reader) u64 {
    var sum: u64 = 0;

    // Remove this vvv
    if (reader.data.len > 0) {
        sum += 1;
    }
    // Remove this ^^^

    return sum;
}

pub fn part1_benchmark() void {
    benchmark.benchmark(benchmark.BenchmarkOptions{ .func = struct {
        fn run() void {
            var reader = Reader.from_comptime_path(data_path);
            _ = part_one(&reader);
        }
    }.run, .warm_up_iterations = 5, .iterations = 100 });
}

pub fn part2_benchmark() void {
    benchmark.benchmark(benchmark.BenchmarkOptions{ .func = struct {
        fn run() void {
            var reader = Reader.from_comptime_path(data_path);
            _ = part_two(&reader);
        }
    }.run, .warm_up_iterations = 5, .iterations = 100 });
}

test "part 1 small" {
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1);
}

test "part 2 small" {
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1);
}