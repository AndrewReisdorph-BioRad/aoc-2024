const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const Position = @import("utils/grid.zig").Position;
const Direction = @import("utils/grid.zig").Direction;
const Bitfield = @import("utils/bitfield.zig").Bitfield;
const benchmark = @import("utils/benchmark.zig");

const day = 18;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});

const MapPath = struct { cost: u32 = 0, current: Position = Position{ .x = 0, .y = 0 } };
fn MapPathWithHistory(width: comptime_int, height: comptime_int) type {
    return struct { dead_end: bool = false, visited: Bitfield(width * height) = Bitfield(width * height).init(), current: Position = Position{ .x = 0, .y = 0 } };
}

const ByteIterator = struct {
    reader: *Reader,

    const Self = @This();

    pub fn next(self: *Self) ?Position {
        if (self.reader.search_next_int(i64)) |x| {
            return Position{ .x = x, .y = self.reader.search_next_int(i64).? };
        }
        return null;
    }
};

pub fn part_one(reader: *Reader, width: comptime_int, height: comptime_int, num_bytes: comptime_int) u64 {
    // Setup Map
    var map = Bitfield(width * height).init();
    var count: u32 = 0;
    while (reader.search_next_int(u64)) |x| {
        const y = reader.search_next_int(u64).?;
        map.set(y * width + x);
        count += 1;
        if (count >= num_bytes) {
            break;
        }
    }

    // Find Shortest Path
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var paths = std.ArrayList(MapPath).init(gpa.allocator());
    defer paths.deinit();

    paths.append(MapPath{}) catch unreachable;
    map.set(0);

    while (true) {
        var cheapest_path = &paths.items[0];
        var lowest_cost: usize = std.math.maxInt(usize);
        for (paths.items) |*path| {
            if (path.cost < lowest_cost) {
                lowest_cost = path.cost;
                cheapest_path = path;
            }
        }

        const current_position = cheapest_path.current;
        const current_cost = cheapest_path.cost;
        var appended_current_path = false;

        // investigate paths in all directions
        const all_directions = [_]Direction{ Direction.north, Direction.east, Direction.south, Direction.west };
        for (all_directions) |direction| {
            const new_position = current_position.from_step(direction);
            if (new_position.is_contained(width, height)) {
                if (new_position.x == width - 1 and new_position.y == height - 1) {
                    return current_cost + 1;
                }
                const offset = @as(u64, @intCast(new_position.y * width + new_position.x));
                if (!map.get(offset)) {
                    map.set(offset);
                    if (appended_current_path) {
                        // Create new path for this fork
                        paths.append(MapPath{ .current = new_position, .cost = current_cost + 1 }) catch unreachable;
                    } else {
                        cheapest_path.cost += 1;
                        cheapest_path.current = new_position;
                        appended_current_path = true;
                    }
                }
            }
        }

        if (!appended_current_path) {
            cheapest_path.cost = std.math.maxInt(u32);
        }
    }

    unreachable;
}

fn find_path(width: comptime_int, height: comptime_int, map: *Bitfield(width * height), allocator: std.mem.Allocator) ?MapPathWithHistory(width, height) {
    // Find Shortest Path
    var paths = std.ArrayList(MapPathWithHistory(width, height)).init(allocator);
    defer paths.deinit();

    var global_visited = Bitfield(width * height).init();

    paths.append(MapPathWithHistory(width, height){}) catch unreachable;
    global_visited.set(0);

    while (true) {
        var cheapest_path = &paths.items[0];
        var lowest_cost: usize = std.math.maxInt(usize);
        for (paths.items) |*path| {
            if (!path.dead_end and path.visited.count < lowest_cost) {
                lowest_cost = path.visited.count;
                cheapest_path = path;
            }
        }
        if (lowest_cost == std.math.maxInt(usize)) {
            return null;
        }

        const current_position = cheapest_path.current;
        var current_visited = cheapest_path.visited.clone();
        var appended_current_path = false;

        // investigate paths in all directions
        const all_directions = [_]Direction{ Direction.north, Direction.east, Direction.south, Direction.west };
        for (all_directions) |direction| {
            const new_position = current_position.from_step(direction);
            if (new_position.is_contained(width, height)) {
                if (new_position.x == width - 1 and new_position.y == height - 1) {
                    return cheapest_path.*;
                }
                const offset = @as(u64, @intCast(new_position.y * width + new_position.x));
                if (!map.get(offset) and !global_visited.get(offset)) {
                    global_visited.set(offset);
                    if (appended_current_path) {
                        // Create new path for this fork
                        paths.append(MapPathWithHistory(width, height){ .current = new_position, .visited = current_visited.clone() }) catch unreachable;
                        paths.items[paths.items.len - 1].visited.set(offset);
                    } else {
                        cheapest_path.visited.set(offset);
                        cheapest_path.current = new_position;
                        appended_current_path = true;
                    }
                }
            }
        }

        if (!appended_current_path) {
            cheapest_path.dead_end = true;
        }
    }
}

pub fn part_two(reader: *Reader, width: comptime_int, height: comptime_int, num_bytes: comptime_int) Position {
    // Setup Map
    var map = Bitfield(width * height).init();
    var byte_iterator = ByteIterator{ .reader = reader };
    var count: u32 = 0;
    while (byte_iterator.next()) |position| {
        map.set(@as(u64, @intCast(position.y * width + position.x)));
        count += 1;
        if (count >= num_bytes) {
            break;
        }
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var cheapest_path = find_path(width, height, &map, gpa.allocator()).?;

    while (byte_iterator.next()) |position| {
        count += 1;
        const offset = @as(u64, @intCast(position.y * width + position.x));
        map.set(offset);
        // If the next byte falls on the current path, recalculate
        if (cheapest_path.visited.get(offset)) {
            if (find_path(width, height, &map, gpa.allocator())) |new_path| {
                cheapest_path = new_path;
            } else {
                return position;
            }
        }
    }

    unreachable;
}

pub fn do_benchmark() void {
    benchmark.benchmark(benchmark.BenchmarkOptions{ .name = std.fmt.comptimePrint("Day {d} Part 1", .{day}), .func = struct {
        fn run() void {
            var reader = Reader.from_comptime_path(data_path);
            _ = part_one(&reader, 71, 71, 1024);
        }
    }.run, .warm_up_iterations = 5 });
    benchmark.benchmark(benchmark.BenchmarkOptions{ .name = std.fmt.comptimePrint("Day {d} Part 2", .{day}), .func = struct {
        fn run() void {
            var reader = Reader.from_comptime_path(data_path);
            _ = part_two(&reader, 71, 71, 1024);
        }
    }.run, .warm_up_iterations = 5 });
}

test "part 1 small" {
    var reader = Reader.init(
        \\5,4
        \\4,2
        \\4,5
        \\3,0
        \\2,1
        \\6,3
        \\2,4
        \\1,5
        \\0,6
        \\3,3
        \\2,6
        \\5,1
        \\1,2
        \\5,5
        \\2,5
        \\6,5
        \\1,4
        \\0,4
        \\6,4
        \\1,1
        \\6,1
        \\1,0
        \\0,5
        \\1,6
        \\2,0        
    );
    const result = part_one(&reader, 7, 7, 12);
    try std.testing.expectEqual(22, result);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader, 71, 71, 1024);
    try std.testing.expectEqual(278, result);
}

test "part 2 small" {
    var reader = Reader.init(
        \\5,4
        \\4,2
        \\4,5
        \\3,0
        \\2,1
        \\6,3
        \\2,4
        \\1,5
        \\0,6
        \\3,3
        \\2,6
        \\5,1
        \\1,2
        \\5,5
        \\2,5
        \\6,5
        \\1,4
        \\0,4
        \\6,4
        \\1,1
        \\6,1
        \\1,0
        \\0,5
        \\1,6
        \\2,0        
    );
    const result = part_two(&reader, 7, 7, 12);
    try std.testing.expectEqual(Position{ .x = 6, .y = 1 }, result);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader, 71, 71, 1024);
    try std.testing.expectEqual(Position{ .x = 0, .y = 0 }, result);
}
