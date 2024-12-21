const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const Grid = @import("utils/grid.zig").Grid;
const Position = @import("utils/grid.zig").Position;
const Direction = @import("utils/grid.zig").Direction;

const benchmark = @import("utils/benchmark.zig");

const day = 20;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});

const TRACK = '.';
const WALL = '#';
const START = 'S';
const END = 'E';

pub fn part_one(reader: *Reader) u64 {
    var allocator = std.heap.page_allocator;
    var grid = Grid.init(reader.data);
    var cost_map = allocator.alloc(u16, grid.width * grid.height) catch unreachable;
    @memset(cost_map, 0);

    // Determine the cost of each tile along the path
    const start_offset = reader.seek_to_next_substr(&.{START}).?;
    const end_offset = reader.seek_to_next_substr(&.{END}).?;
    const end_position = grid.get_position_from_offset(end_offset).?;
    const start_position = grid.get_position_from_offset(start_offset).?;
    var current_position = end_position;
    const all_directions: [4]Direction = .{ Direction.north, Direction.east, Direction.south, Direction.west };

    var current_cost: u16 = 0;
    while (!std.meta.eql(current_position, start_position)) {
        for (all_directions) |direction| {
            const test_position = current_position.from_step(direction);
            const test_offset = grid.get_position_offset(test_position).?;
            if (grid.read(test_position) != WALL and cost_map[test_offset] == 0) {
                current_position = test_position;
                break;
            }
        }
        cost_map[grid.get_position_offset(current_position).?] = current_cost;
        current_cost += 1;
    }

    std.debug.print("Total cost: {d}\n", .{current_cost});

    var short_cut_counts = std.AutoHashMap(i32, u16).init(allocator);

    var good_time_saves: u64 = 0;

    // Test each position
    var last_position = current_position;
    current_position = start_position;
    while (!std.meta.eql(current_position, end_position)) {
        std.debug.print("Testing {d},{d} for cheats.\n", .{ current_position.x, current_position.y });
        for (all_directions) |direction| {
            const first_cheat_wall_position = current_position.from_step(direction);
            if (grid.read(first_cheat_wall_position) == '#') {
                std.debug.print("  Has wall to {any}. Testing for length 1 cheats\n", .{direction});
                // Check if a 1 wall cheat can be activated
                for (all_directions) |empty_wall_direction| {
                    const track_position = first_cheat_wall_position.from_step(empty_wall_direction);
                    const at_position = grid.read(track_position);
                    if (!std.meta.eql(current_position, track_position) and (at_position == TRACK or at_position == END)) {
                        const time_saved = @as(i32, cost_map[grid.get_position_offset(current_position).?]) - @as(i32, cost_map[grid.get_position_offset(track_position).?]) - 2;
                        std.debug.print("  Found track at {any} with savings: {d}\n", .{ track_position, time_saved });
                        if (time_saved >= 100) {
                            good_time_saves += 1;
                            const result = short_cut_counts.getOrPut(time_saved) catch unreachable;
                            if (result.found_existing) {
                                result.value_ptr.* += 1;
                            } else {
                                result.value_ptr.* = 1;
                            }
                        }
                    }
                }
                std.debug.print("  -------------------\n", .{});
            }
        }

        // Move to the next position in the track
        for (all_directions) |direction| {
            const next_position = current_position.from_step(direction);
            if (!std.meta.eql(last_position, next_position) and grid.read(next_position) != WALL) {
                last_position = current_position;
                current_position = next_position;
                break;
            }
        }
    }

    var iter = short_cut_counts.iterator();
    while (iter.next()) |entry| {
        std.debug.print("{d}: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    return good_time_saves;
}

pub fn part_two(reader: *Reader) u64 {
    _ = reader;

    return 0;
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
        \\###############
        \\#...#...#.....#
        \\#.#.#.#.#.###.#
        \\#S#...#.#.#...#
        \\#######.#.#.###
        \\#######.#.#...#
        \\#######.#.###.#
        \\###..E#...#...#
        \\###.#######.###
        \\#...###...#...#
        \\#.#####.#.###.#
        \\#.#...#.#.#...#
        \\#.#.#.#.#.#.###
        \\#...#...#...###
        \\###############
    );
    const result = part_one(&reader);
    try std.testing.expectEqual(1, result);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    try std.testing.expectEqual(1, result);
}

test "part 2 small" {
    var reader = Reader.init(
        \\sample data
        \\goes here
    );
    const result = part_two(&reader);
    try std.testing.expectEqual(1, result);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    try std.testing.expectEqual(1, result);
}
