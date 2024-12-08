const std = @import("std");
const Reader = @import("reader.zig").Reader;
const Grid = @import("grid.zig").Grid;
const Direction = @import("grid.zig").Direction;
const Position = @import("grid.zig").Position;
const benchmark = @import("benchmark.zig");

const day = 4;
const data_path = std.fmt.comptimePrint("./data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("./data/day{d}_small.txt", .{day});

fn search_string(grid: *Grid, position: Position, direction: Direction, string: []const u8) bool {
    var candidate_position = position;

    for (string) |c| {
        if (grid.read(candidate_position) != c) {
            return false;
        }
        candidate_position.move_direction(direction);
    }

    return true;
}

pub fn part_one(reader: *Reader) u64 {
    var sum: u64 = 0;

    var grid = Grid.init(reader.get_data());
    const directions: []const Direction = &.{
        Direction.north,
        Direction.east,
        Direction.south,
        Direction.west,
        Direction.northeast,
        Direction.northwest,
        Direction.southeast,
        Direction.southwest,
    };

    const needle = "XMAS".*;
    var position_iterator = grid.iter_positions();
    while (position_iterator.next()) |p| {
        if (grid.read(p) != 'X') {
            continue;
        }
        for (directions) |direction| {
            if (search_string(&grid, p, direction, &needle)) {
                sum += 1;
            }
        }
    }

    return sum;
}

pub fn part_two_naive(reader: *Reader) u64 {
    var sum: u64 = 0;
    var grid = Grid.init(reader.get_data());
    const directions: []const Direction = &.{
        Direction.northwest,
        Direction.northeast,
        Direction.southwest,
        Direction.southeast,
    };

    var positions = std.AutoHashMap(u64, void).init(std.heap.page_allocator);

    const needle = "MAS".*;
    var position_iterator = grid.iter_positions();
    while (position_iterator.next()) |p| {
        for (directions) |direction| direction_loop: {
            switch (search_string(&grid, p, direction, &needle)) {
                .found => {
                    var a_position = p;
                    a_position.move_direction(direction);
                    const a_offset = grid.get_position_offset(a_position).?;
                    if (positions.get(a_offset) == null) {
                        positions.put(a_offset, {}) catch unreachable;
                    } else {
                        sum += 1;
                    }
                },
                .found_partial => continue,
                .not_found => break :direction_loop,
            }
        }
    }

    return sum;
}

pub fn part_two(reader: *Reader) u64 {
    var sum: u64 = 0;
    var grid = Grid.init(reader.get_data());
    var position_iterator = grid.iter_positions();

    while (position_iterator.next()) |p| {
        if (grid.read(p) == 'A') {
            var ne = p;
            ne.move_direction(Direction.northeast);
            var sw = p;
            sw.move_direction(Direction.southwest);
            var read = .{ grid.read(ne), grid.read(sw) };

            if (!((read[0] == 'M' and read[1] == 'S') or
                (read[0] == 'S' and read[1] == 'M')))
            {
                continue;
            }

            var se = p;
            se.move_direction(Direction.southeast);
            var nw = p;
            nw.move_direction(Direction.northwest);
            read = .{ grid.read(se), grid.read(nw) };

            if ((read[0] == 'M' and read[1] == 'S') or
                (read[0] == 'S' and read[1] == 'M'))
            {
                sum += 1;
            }
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
    try std.testing.expect(result == 18);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 2468);
}

test "part 2 small" {
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 9);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1864);
}
