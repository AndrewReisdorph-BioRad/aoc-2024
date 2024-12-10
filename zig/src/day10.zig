const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const Grid = @import("utils/grid.zig").Grid;
const Position = @import("utils/grid.zig").Position;
const Direction = @import("utils/grid.zig").Direction;
const benchmark = @import("utils/benchmark.zig");
const Bitfield = @import("utils/bitfield.zig").Bitfield;
const Stack = @import("utils/stack.zig").Stack;

const day = 10;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("../data/day{d}_small.txt", .{day});

pub fn get_trailhead_score(grid: *Grid, position: Position) u64 {
    var score: u64 = 0;
    var positions_to_explore = Stack(Position, 9).init();
    positions_to_explore.push(position) catch @panic("Could not push to stack");

    var visited = Bitfield(60 * 60).init();
    const all_directions: [4]Direction = .{ Direction.north, Direction.east, Direction.south, Direction.west };

    while (positions_to_explore.pop()) |current_position| {
        const current_value = grid.read(current_position).?;
        if (current_value == '9') {
            score += 1;
            continue;
        }
        for (all_directions) |direction| {
            const test_position = current_position.from_step(direction);
            if (grid.get_position_offset(test_position)) |offset| {
                const value_at_position = grid.read(test_position).?;
                const position_is_one_more_than_current = value_at_position == (current_value + 1);
                if (visited.get(offset) or !position_is_one_more_than_current) {
                    continue;
                }
                visited.set(offset);
                positions_to_explore.push(test_position) catch @panic("Could not push to stack");
            }
        }
    }

    return score;
}

pub fn get_trailhead_score_part_2(grid: *Grid, position: Position) u64 {
    var score: u64 = 0;
    var positions_to_explore = Stack(Position, 9).init();
    positions_to_explore.push(position) catch @panic("Could not push to stack");

    const all_directions: [4]Direction = .{ Direction.north, Direction.east, Direction.south, Direction.west };

    while (positions_to_explore.pop()) |current_position| {
        const current_value = grid.read(current_position).?;
        if (current_value == '9') {
            score += 1;
            continue;
        }
        for (all_directions) |direction| {
            const test_position = current_position.from_step(direction);
            if (grid.read(test_position)) |at_position| {
                const position_is_one_more_than_current = at_position == (current_value + 1);
                if (!position_is_one_more_than_current) {
                    continue;
                }
                positions_to_explore.push(test_position) catch @panic("Could not push to stack");
            }
        }
    }

    return score;
}

pub fn part_one(reader: *Reader) u64 {
    var grid = Grid.init(reader.get_data());
    var sum: u64 = 0;

    var position_iter = grid.iter_positions();
    while (position_iter.next()) |position| {
        if (grid.read(position).? == '0') {
            sum += get_trailhead_score(&grid, position);
        }
    }

    return sum;
}

pub fn part_two(reader: *Reader) u64 {
    var grid = Grid.init(reader.get_data());
    var sum: u64 = 0;

    var position_iter = grid.iter_positions();
    while (position_iter.next()) |position| {
        if (grid.read(position).? == '0') {
            const score = get_trailhead_score_part_2(&grid, position);
            sum += score;
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
    std.debug.print("\n", .{});
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 36);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 786);
}

test "part 2 small" {
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 81);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1722);
}
