const std = @import("std");
const Reader = @import("reader.zig").Reader;
const BitField = @import("utils/bitfield.zig").Bitfield;
const AsciiMap = @import("utils/ascii_map.zig").AsciiMap;
const Position = @import("grid.zig").Position;
const PositionIterator = @import("grid.zig").PositionIterator;
const Grid = @import("grid.zig").Grid;
const benchmark = @import("benchmark.zig");

const day = 8;
const data_path = std.fmt.comptimePrint("./data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("./data/day{d}_small.txt", .{day});

const AntennaPosition = struct { position: Position, processed: bool };

pub fn part_one(reader: *Reader) u64 {
    var grid = Grid.init(reader.get_data());

    // Keep track of the last processed antenna location
    var antenna_map = AsciiMap(std.ArrayList(AntennaPosition)).init();
    // Keep track of antinode locations
    var antinodes = BitField(2600).init();

    // Read In Data
    var position_iterator = grid.iter_positions();
    while (position_iterator.next()) |position| {
        const at_position = grid.read(position).?;
        if (at_position == '.') {
            continue;
        }
        if (!antenna_map.has(at_position)) {
            antenna_map.set(at_position, std.ArrayList(AntennaPosition).init(std.heap.page_allocator));
        }
        antenna_map.get(at_position).?.append(AntennaPosition{ .position = position, .processed = false }) catch unreachable;
    }

    for ('0'..('z' + 1)) |antenna| {
        const char = @as(u8, @intCast(antenna));
        if (antenna_map.get(char)) |entry| {
            for (0..entry.items.len - 1) |i| {
                const position_i = entry.items[i].position;
                for (i + 1..entry.items.len) |j| {
                    const position_j = entry.items[j].position;

                    var position_delta = position_i.delta(position_j);
                    var forward_delta_position = position_i.clone();
                    forward_delta_position.apply_delta(position_delta);
                    var backward_delta_position = position_j.clone();
                    backward_delta_position.apply_delta(position_delta.invert().*);

                    if (grid.get_position_offset(forward_delta_position)) |offset| {
                        antinodes.set(offset);
                    }
                    if (grid.get_position_offset(backward_delta_position)) |offset| {
                        antinodes.set(offset);
                    }
                }
            }
        }
    }

    // Benchmarks are better without free-ing memory!
    // for (antenna_map.inner) |maybe_entry| {
    //     if (maybe_entry) |entry| {
    //         entry.deinit();
    //     }
    // }

    return @as(u64, antinodes.count);
}

pub fn part_two(reader: *Reader) u64 {
    var grid = Grid.init(reader.get_data());

    // Keep track of the last processed antenna location
    var antenna_map = AsciiMap(std.ArrayList(AntennaPosition)).init();
    // Keep track of antinode locations
    var antinodes = BitField(2600).init();

    // Read In Data
    var position_iterator = grid.iter_positions();
    while (position_iterator.next()) |position| {
        const at_position = grid.read(position).?;
        if (at_position == '.') {
            continue;
        }
        if (!antenna_map.has(at_position)) {
            antenna_map.set(at_position, std.ArrayList(AntennaPosition).init(std.heap.page_allocator));
        }
        antenna_map.get(at_position).?.append(AntennaPosition{ .position = position, .processed = false }) catch unreachable;
    }

    for ('0'..('z' + 1)) |antenna| {
        const char = @as(u8, @intCast(antenna));
        if (antenna_map.get(char)) |entry| {
            for (0..entry.items.len - 1) |i| {
                const position_i = entry.items[i].position;
                if (i == 0) {
                    antinodes.set(grid.get_position_offset(position_i).?);
                }
                for (i + 1..entry.items.len) |j| {
                    const position_j = entry.items[j].position;
                    antinodes.set(grid.get_position_offset(position_j).?);

                    // Create antinodes with forward delta
                    var forward_delta = position_i.delta(position_j);
                    var forward_delta_position = position_i.clone();
                    while (true) {
                        forward_delta_position.apply_delta(forward_delta);
                        if (grid.get_position_offset(forward_delta_position)) |offset| {
                            antinodes.set(offset);
                        } else {
                            break;
                        }
                    }

                    // Create antinodes with backward delta
                    var backward_delta_position = position_j.clone();
                    const backward_delta = forward_delta.invert().*;
                    while (true) {
                        backward_delta_position.apply_delta(backward_delta);
                        if (grid.get_position_offset(backward_delta_position)) |offset| {
                            antinodes.set(offset);
                        } else {
                            break;
                        }
                    }
                }
            }
        }
    }

    // Benchmarks are better without free-ing memory!
    // for (antenna_map.inner) |maybe_entry| {
    //     if (maybe_entry) |entry| {
    //         entry.deinit();
    //     }
    // }

    return @as(u64, antinodes.count);
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
    try std.testing.expect(result == 14);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 278);
}

test "part 2 small" {
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 34);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1);
}
