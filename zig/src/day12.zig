const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const benchmark = @import("utils/benchmark.zig");
const Grid = @import("utils/grid.zig").Grid;
const Position = @import("utils/grid.zig").Position;
const Direction = @import("utils/grid.zig").Direction;
const Bitfield = @import("utils/bitfield.zig").Bitfield;
const Stack = @import("utils/stack.zig").Stack;

const day = 12;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("../data/day{d}_small.txt", .{day});

fn get_area_cost(position: Position, grid: *Grid, processed: anytype) u64 {
    var area: u64 = 1;
    var perimeter: u64 = 0;
    var to_visit = Stack(Position, 115).init();
    const area_id = grid.read(position).?;
    to_visit.push(position) catch unreachable;
    processed.set(grid.get_position_offset(position).?);

    const all_directions: [4]Direction = .{ Direction.north, Direction.east, Direction.south, Direction.west };

    while (to_visit.pop()) |next_position| {
        for (all_directions) |direction| {
            const candidate_position = next_position.from_step(direction);
            if (grid.read(candidate_position)) |at_candidate_position| {
                if (at_candidate_position == area_id) {
                    if (!processed.get(grid.get_position_offset(candidate_position).?)) {
                        processed.set(grid.get_position_offset(candidate_position).?);
                        area += 1;
                        to_visit.push(candidate_position) catch unreachable;
                    }
                } else {
                    perimeter += 1;
                }
            } else {
                perimeter += 1;
            }
        }
    }

    return area * perimeter;
}

fn get_side_count_cost(position: Position, grid: *Grid, processed: anytype) u64 {
    var area: u64 = 1;
    var sides: u64 = 0;
    var to_visit = Stack(Position, 115).init();
    const area_id = grid.read(position).?;
    to_visit.push(position) catch unreachable;
    processed.set(grid.get_position_offset(position).?);

    const cardinal_directions: [4]Direction = .{ Direction.north, Direction.east, Direction.south, Direction.west };
    const inter_cardinal_directions: [4]Direction = .{ Direction.northeast, Direction.southeast, Direction.southwest, Direction.northwest };

    const outside_corner_masks: [4]u8 = .{
        @intFromEnum(Direction.east) | @intFromEnum(Direction.south),
        @intFromEnum(Direction.east) | @intFromEnum(Direction.north),
        @intFromEnum(Direction.west) | @intFromEnum(Direction.south),
        @intFromEnum(Direction.west) | @intFromEnum(Direction.north),
    };

    const inside_corner_masks: [4][2]u8 = .{
        .{ @intFromEnum(Direction.east) | @intFromEnum(Direction.south), @intFromEnum(Direction.southeast) },
        .{ @intFromEnum(Direction.east) | @intFromEnum(Direction.north), @intFromEnum(Direction.northeast) },
        .{ @intFromEnum(Direction.west) | @intFromEnum(Direction.south), @intFromEnum(Direction.southwest) },
        .{ @intFromEnum(Direction.west) | @intFromEnum(Direction.north), @intFromEnum(Direction.northwest) },
    };

    while (to_visit.pop()) |next_position| {
        var neighbor_bits: u8 = 0;

        // Find next tiles in this area
        for (cardinal_directions) |direction| {
            const candidate_position = next_position.from_step(direction);
            if (grid.read(candidate_position)) |at_candidate_position| {
                if (at_candidate_position == area_id) {
                    neighbor_bits |= @intFromEnum(direction);
                    if (!processed.get(grid.get_position_offset(candidate_position).?)) {
                        processed.set(grid.get_position_offset(candidate_position).?);
                        area += 1;
                        to_visit.push(candidate_position) catch unreachable;
                    }
                }
            }
        }

        // Detect features of this tile
        for (inter_cardinal_directions) |direction| {
            const candidate_position = next_position.from_step(direction);
            if (grid.read(candidate_position)) |at_candidate_position| {
                if (at_candidate_position == area_id) {
                    neighbor_bits |= @intFromEnum(direction);
                }
            }
        }

        // Count outside corners
        for (outside_corner_masks) |mask| {
            // All mask bits clear
            if ((neighbor_bits & mask) == 0) {
                sides += 1;
            }
        }

        // Count inside corners
        for (inside_corner_masks) |masks| {
            // First mask bits set and second mask bits clear
            if (((neighbor_bits & masks[0]) == masks[0]) and (neighbor_bits & masks[1]) == 0) {
                sides += 1;
            }
        }
    }

    return area * sides;
}

pub fn part_one(reader: *Reader) u64 {
    var grid = Grid.init(reader.get_data());

    var processed = Bitfield(141 * 141).init();
    var position_iter = grid.iter_positions();
    var sum: u64 = 0;
    while (position_iter.next()) |position| {
        const offset = grid.get_position_offset(position).?;
        if (processed.get(offset)) {
            continue;
        }
        sum += get_area_cost(position, &grid, &processed);
    }

    return sum;
}

pub fn part_two(reader: *Reader) u64 {
    var grid = Grid.init(reader.get_data());

    var processed = Bitfield(141 * 141).init();
    var position_iter = grid.iter_positions();
    var sum: u64 = 0;
    while (position_iter.next()) |position| {
        const offset = grid.get_position_offset(position).?;
        if (processed.get(offset)) {
            continue;
        }
        sum += get_side_count_cost(position, &grid, &processed);
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
    try std.testing.expect(result == 1930);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1549354);
}

test "part 2 small" {
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1206);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 937032);
}
