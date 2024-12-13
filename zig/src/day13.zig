const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const SeekFrom = @import("utils/reader.zig").SeekFrom;
const benchmark = @import("utils/benchmark.zig");

const day = 13;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("../data/day{d}_small.txt", .{day});

const a_button_cost = 3;
const b_button_cost = 1;

const ButtonData = struct { ax: i64, ay: i64, bx: i64, by: i64, prize_x: i64, prize_y: i64 };

fn get_next_button_data(reader: *Reader) ?ButtonData {
    if (reader.next_line()) |first_line| {
        const ax = @as(u32, first_line[12] - 48) * 10 + @as(u32, first_line[13] - 48);
        const ay = @as(u32, first_line[18] - 48) * 10 + @as(u32, first_line[19] - 48);
        const next_line = reader.next_line().?;
        const bx = @as(u32, next_line[12] - 48) * 10 + @as(u32, next_line[13] - 48);
        const by = @as(u32, next_line[18] - 48) * 10 + @as(u32, next_line[19] - 48);

        reader.seek(SeekFrom.Current, 9);
        var prize_x: i64 = 0;
        while (true) {
            const char = reader.next_char().?;
            if (char == ',') {
                break;
            } else {
                prize_x = prize_x * 10 + (@as(i64, char) - 48);
            }
        }

        reader.seek(SeekFrom.Current, 3);
        var prize_y: i64 = 0;
        while (reader.next_char()) |char| {
            if (char == '\n') {
                break;
            } else {
                prize_y = prize_y * 10 + (@as(i64, char) - 48);
            }
        }

        // eat the next empty line
        reader.seek(SeekFrom.Current, 1);

        return ButtonData{ .ax = ax, .ay = ay, .bx = bx, .by = by, .prize_x = prize_x, .prize_y = prize_y };
    }
    return null;
}

fn float_has_fractional_part(value: f64) bool {
    const value_without_fractional_part = @as(@TypeOf(value), @floatFromInt(@as(i64, @intFromFloat(value))));
    return value != value_without_fractional_part;
}

fn solve(button_data: ButtonData) ?u64 {
    const a_presses: f64 = @as(f64, @floatFromInt(button_data.by * button_data.prize_x - button_data.bx * button_data.prize_y)) / @as(f64, @floatFromInt(button_data.by * button_data.ax - button_data.bx * button_data.ay));
    if (float_has_fractional_part(a_presses)) {
        return null;
    }
    const b_presses = (@as(f64, @floatFromInt(button_data.prize_y)) - (@as(f64, @floatFromInt(button_data.ay)) * a_presses)) / @as(f64, @floatFromInt(button_data.by));
    if (float_has_fractional_part(b_presses)) {
        return null;
    }
    return @as(u64, @intFromFloat(a_presses * a_button_cost + b_presses * b_button_cost));
}

pub fn part_one(reader: *Reader) u64 {
    var sum: u64 = 0;

    while (get_next_button_data(reader)) |button_data| {
        if (solve(button_data)) |result| {
            sum += result;
        }
    }

    return sum;
}

pub fn part_two(reader: *Reader) u64 {
    var sum: u64 = 0;

    const offset = 10000000000000;

    while (get_next_button_data(reader)) |button_data| {
        var updated_button = button_data;
        updated_button.prize_x += offset;
        updated_button.prize_y += offset;
        if (solve(updated_button)) |result| {
            sum += result;
        }
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
    try std.testing.expect(result == 480);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 36250);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 83232379451012);
}
