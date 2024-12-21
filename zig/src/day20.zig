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
    defer allocator.free(cost_map);
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

    var good_time_saves: u64 = 0;

    // Test each position
    var last_position = current_position;
    current_position = start_position;
    while (!std.meta.eql(current_position, end_position)) {
        for (all_directions) |direction| {
            const first_cheat_wall_position = current_position.from_step(direction);
            if (grid.read(first_cheat_wall_position) == '#') {
                // Check if a 1 wall cheat can be activated
                for (all_directions) |empty_wall_direction| {
                    const track_position = first_cheat_wall_position.from_step(empty_wall_direction);
                    const at_position = grid.read(track_position);
                    if (!std.meta.eql(current_position, track_position) and (at_position == TRACK or at_position == END)) {
                        const time_saved = @as(i32, cost_map[grid.get_position_offset(current_position).?]) - @as(i32, cost_map[grid.get_position_offset(track_position).?]) - 2;
                        if (time_saved >= 100) {
                            good_time_saves += 1;
                        }
                    }
                }
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

    return good_time_saves;
}

const DiamondPositionIter = struct {
    const Self = @This();
    center_x: i64,
    center_y: i64,
    size: usize,
    y_progress: i64 = 0,
    x_progress: i64 = 0,
    current_width: i64 = 1,
    width_delta: i64 = 2,
    done: bool = false,

    pub fn init(center_x: i64, center_y: i64, size: usize) Self {
        return Self{ .center_x = center_x, .center_y = center_y, .size = size, .y_progress = @as(i64, @intCast(size)) * -1 };
    }

    pub fn next(self: *Self) ?Position {
        var next_x: i64 = 0;
        var next_y: i64 = 0;

        if (self.done) {
            return null;
        }

        if (self.x_progress >= self.current_width) {
            self.y_progress += 1;
            if (self.current_width == ((self.size * 2) + 1)) {
                self.width_delta = -2;
            }
            self.current_width += self.width_delta;
            if (self.current_width <= 0) {
                self.done = true;
                return null;
            }
            self.x_progress = 0;
        }

        next_x = self.center_x - @divExact((@as(i64, @intCast(self.current_width)) - 1), 2) + self.x_progress;
        next_y = self.center_y + self.y_progress;

        self.x_progress += 1;

        return Position{ .x = next_x, .y = next_y };
    }
};

pub fn part_two(reader: *Reader) u64 {
    var allocator = std.heap.page_allocator;
    var grid = Grid.init(reader.data);
    var cost_map = allocator.alloc(u16, grid.width * grid.height) catch unreachable;
    defer allocator.free(cost_map);
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

    var good_time_saves: u64 = 0;

    // Test each position
    var last_position = current_position;
    current_position = start_position;
    while (!std.meta.eql(current_position, end_position)) {
        // Check for all positions in diamond around current position
        var position_iter = DiamondPositionIter.init(current_position.x, current_position.y, 20);
        while (position_iter.next()) |pos| {
            if (grid.read(pos)) |at_position| {
                if (at_position == TRACK or at_position == END) {
                    const time_saved = @as(i32, cost_map[grid.get_position_offset(current_position).?]) - @as(i32, cost_map[grid.get_position_offset(pos).?]) - @as(i32, @intCast(pos.step_distance(current_position)));
                    if (time_saved >= 100) {
                        good_time_saves += 1;
                    }
                }
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

    return good_time_saves;
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
    try std.testing.expectEqual(1351, result);
}

test "part 2 small" {
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
    const result = part_two(&reader); // 285
    try std.testing.expectEqual(1, result);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    try std.testing.expectEqual(966130, result);
}
