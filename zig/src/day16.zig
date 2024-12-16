const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const Grid = @import("utils/grid.zig").Grid;
const Direction = @import("utils/grid.zig").Direction;
const Position = @import("utils/grid.zig").Position;
// const Bitfield = @import("utils/bitfield.zig").Bitfield;

const benchmark = @import("utils/benchmark.zig");

const day = 16;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("../data/day{d}_small.txt", .{day});

const WALL = '#';
const START = 'S';
const END = 'E';
const EMPTY = '.';

const map_size = 142 * 142;

const VisitInfo = struct {
    const Self = @This();
    costs: [4]?u64,

    pub fn updateIfCheaper(self: *Self, cost: u64, direction: Direction) void {
        const index = std.math.log2_int(u8, @intFromEnum(direction));
        if (self.costs[index]) |old_cost| {
            if (cost < old_cost) {
                self.costs[index] = cost;
            }
        } else {
            self.costs[index] = cost;
        }
    }

    pub fn hasCheaper(self: *Self, cost: u64, direction: Direction) bool {
        const index = std.math.log2_int(u8, @intFromEnum(direction));
        if (self.costs[index]) |old_cost| {
            return old_cost < cost;
        }
        return false;
    }
};

const VisitedMapPositions = std.AutoHashMap(u64, void);

const MapPath = struct { direction: Direction, cost: u64, current: Position, disqualified: bool, complete: bool = false, optimal: bool = false, visited: VisitedMapPositions };

pub fn part_one(reader: *Reader) u64 {
    var grid = Grid.init(reader.get_data());

    // find start and end
    var grid_iter = grid.iter_positions();
    var start_position: Position = undefined;
    var end_position: Position = undefined;
    while (grid_iter.next()) |position| {
        const at_position = grid.read(position).?;
        if (at_position == 'S') {
            start_position = position;
        } else if (at_position == 'E') {
            end_position = position;
        }
    }

    var paths = std.ArrayList(MapPath).init(std.heap.page_allocator);
    defer paths.deinit();

    const initial_path = MapPath{ .direction = Direction.east, .cost = 0, .current = start_position, .disqualified = false, .visited = VisitedMapPositions.init(std.heap.page_allocator) };
    paths.append(initial_path) catch unreachable;

    var global_visited = std.heap.page_allocator.alloc(u8, map_size) catch unreachable;
    defer std.heap.page_allocator.free(global_visited);
    @memset(global_visited, 0);

    var cheapest_path = &paths.items[0];

    while (true) {
        // Find the lowest cost path
        var lowest_cost: u64 = std.math.maxInt(u64);
        for (paths.items) |*path| {
            if (!path.disqualified and path.cost < lowest_cost) {
                cheapest_path = path;
                lowest_cost = path.cost;
            }
        }
        // std.debug.print("Current Path Length: {d} Cost: {d}\n", .{ cheapest_path.visited.count(), cheapest_path.cost });
        if (lowest_cost == std.math.maxInt(u64)) {
            @panic("All paths lead to dead end");
        }
        global_visited[grid.get_position_offset(cheapest_path.current).?] |= @intFromEnum(cheapest_path.direction);
        cheapest_path.visited.put(grid.get_position_offset(cheapest_path.current).?, {}) catch unreachable;

        const current_cost = cheapest_path.cost;
        const current_head = cheapest_path.current;
        const current_direction = cheapest_path.direction;
        var current_visited = cheapest_path.visited.clone() catch unreachable;

        // Step forward if possible
        const forward_position = cheapest_path.current.from_step(cheapest_path.direction);
        var position_offset = grid.get_position_offset(forward_position).?;
        var global_position_entry = &global_visited[position_offset];
        var moved_forward = false;
        const at_forward = grid.read(forward_position).?;
        var position_visited_from_this_path = current_visited.get(position_offset) != null;
        var position_visited_from_same_direction = (global_position_entry.* & @intFromEnum(cheapest_path.direction)) > 0;
        if (!position_visited_from_this_path and !position_visited_from_same_direction and at_forward != WALL) {
            if (at_forward == EMPTY) {
                cheapest_path.cost += 1;
                cheapest_path.current = forward_position;
                moved_forward = true;
            } else if (at_forward == END) {
                cheapest_path.cost += 1;
                break;
            }
        }

        var turned_left = false;
        const left_direction = current_direction.from_90_degree_counter_clockwise_turn();
        const left_position = current_head.from_step(left_direction);
        const at_left = grid.read(left_position).?;
        position_offset = grid.get_position_offset(left_position).?;
        global_position_entry = &global_visited[position_offset];
        position_visited_from_this_path = current_visited.get(position_offset) != null;
        position_visited_from_same_direction = (global_position_entry.* & @intFromEnum(left_direction)) > 0;
        if (!position_visited_from_this_path and !position_visited_from_same_direction and at_left != WALL) {
            turned_left = true;
            var left_path = cheapest_path;
            if (moved_forward) {
                // Create a new path for this branch
                const new_path = MapPath{ .visited = current_visited.clone() catch unreachable, .cost = current_cost, .current = current_head, .direction = left_direction, .disqualified = false };
                paths.append(new_path) catch unreachable;
                left_path = &paths.items[paths.items.len - 1];
            }
            left_path.direction = left_direction;
            left_path.cost += 1000;
        }

        var free_current_visited_copy = true;
        var turned_right = false;
        const right_direction = current_direction.from_90_degree_clockwise_turn();
        const right_position = current_head.from_step(right_direction);
        const at_right = grid.read(right_position).?;
        position_offset = grid.get_position_offset(right_position).?;
        global_position_entry = &global_visited[position_offset];
        position_visited_from_this_path = current_visited.get(position_offset) != null;
        position_visited_from_same_direction = (global_position_entry.* & @intFromEnum(right_direction)) > 0;
        if (!position_visited_from_this_path and !position_visited_from_same_direction and at_right != WALL) {
            turned_right = true;
            var right_path = cheapest_path;
            if (moved_forward or turned_left) {
                free_current_visited_copy = false;
                // Create a new path for this branch
                const new_path = MapPath{ .visited = current_visited, .cost = current_cost, .current = current_head, .direction = right_direction, .disqualified = false };
                paths.append(new_path) catch unreachable;
                right_path = &paths.items[paths.items.len - 1];
            }
            right_path.direction = right_direction;
            right_path.cost += 1000;
        }

        if (!moved_forward and !turned_left and !turned_right) {
            cheapest_path.disqualified = true;
        }

        if (free_current_visited_copy) {
            current_visited.deinit();
        }
    }

    for (paths.items) |*path| {
        path.visited.deinit();
    }

    return cheapest_path.cost;
}

pub fn part_two(reader: *Reader) u64 {
    var grid = Grid.init(reader.get_data());

    // find start and end
    var grid_iter = grid.iter_positions();
    var start_position: Position = undefined;
    var end_position: Position = undefined;
    while (grid_iter.next()) |position| {
        const at_position = grid.read(position).?;
        if (at_position == 'S') {
            start_position = position;
        } else if (at_position == 'E') {
            end_position = position;
        }
    }

    var paths = std.ArrayList(MapPath).init(std.heap.page_allocator);
    defer paths.deinit();

    const initial_path = MapPath{ .direction = Direction.east, .cost = 0, .current = start_position, .disqualified = false, .visited = VisitedMapPositions.init(std.heap.page_allocator) };
    paths.append(initial_path) catch unreachable;

    var global_visited = std.heap.page_allocator.alloc(VisitInfo, map_size) catch unreachable;
    defer std.heap.page_allocator.free(global_visited);
    for (0..map_size) |i| {
        global_visited[i].costs = .{ null, null, null, null };
    }

    var cheapest_path = &paths.items[0];

    var optimal_cost: ?u64 = null;

    while (true) {
        // Find the lowest cost path
        var lowest_cost: u64 = std.math.maxInt(u64);
        for (paths.items) |*path| {
            if (!path.disqualified and !path.complete and path.cost < lowest_cost) {
                if (optimal_cost) |optimal| {
                    if (path.cost > optimal) {
                        path.disqualified = true;
                        continue;
                    }
                }
                cheapest_path = path;
                lowest_cost = path.cost;
            }
        }
        // std.debug.print("Current Path Length: {d} Cost: {d}\n", .{ cheapest_path.visited.count(), cheapest_path.cost });
        if (lowest_cost == std.math.maxInt(u64)) {
            if (optimal_cost == null) {
                @panic("All paths lead to dead end");
            } else {
                break;
            }
        }
        global_visited[grid.get_position_offset(cheapest_path.current).?].updateIfCheaper(cheapest_path.cost, cheapest_path.direction);
        cheapest_path.visited.put(grid.get_position_offset(cheapest_path.current).?, {}) catch unreachable;

        const current_cost = cheapest_path.cost;
        const current_head = cheapest_path.current;
        const current_direction = cheapest_path.direction;
        var current_visited = cheapest_path.visited.clone() catch unreachable;

        // Step forward if possible
        const forward_position = cheapest_path.current.from_step(cheapest_path.direction);
        var position_offset = grid.get_position_offset(forward_position).?;
        var global_visit_entry = &global_visited[position_offset];
        var moved_forward = false;
        const forward_cost = current_cost + 1;
        const at_forward = grid.read(forward_position).?;
        var position_visited_from_this_path = current_visited.get(position_offset) != null;
        var position_visited_from_direction_at_cheaper_cost = global_visit_entry.hasCheaper(forward_cost, current_direction);
        if (!position_visited_from_this_path and !position_visited_from_direction_at_cheaper_cost and at_forward != WALL) {
            if (at_forward == EMPTY) {
                cheapest_path.cost = forward_cost;
                cheapest_path.current = forward_position;
                moved_forward = true;
            } else if (at_forward == END) {
                cheapest_path.cost = forward_cost;
                cheapest_path.complete = true;
                if (optimal_cost) |optimal| {
                    cheapest_path.optimal = cheapest_path.cost == optimal;
                } else {
                    optimal_cost = cheapest_path.cost;
                    cheapest_path.optimal = true;
                }
                continue;
            }
        }

        var turned_left = false;
        const left_direction = current_direction.from_90_degree_counter_clockwise_turn();
        const left_position = current_head.from_step(left_direction);
        const at_left = grid.read(left_position).?;
        const left_cost = current_cost + 1000;
        position_offset = grid.get_position_offset(left_position).?;
        global_visit_entry = &global_visited[position_offset];
        position_visited_from_this_path = current_visited.get(position_offset) != null;
        position_visited_from_direction_at_cheaper_cost = global_visit_entry.hasCheaper(left_cost, left_direction);
        if (!position_visited_from_this_path and !position_visited_from_direction_at_cheaper_cost and at_left != WALL) {
            turned_left = true;
            var left_path = cheapest_path;
            if (moved_forward) {
                // Create a new path for this branch
                const new_path = MapPath{ .visited = current_visited.clone() catch unreachable, .cost = current_cost, .current = current_head, .direction = left_direction, .disqualified = false };
                paths.append(new_path) catch unreachable;
                left_path = &paths.items[paths.items.len - 1];
            }
            left_path.direction = left_direction;
            left_path.cost = left_cost;
        }

        var free_current_visited_copy = true;
        var turned_right = false;
        const right_direction = current_direction.from_90_degree_clockwise_turn();
        const right_position = current_head.from_step(right_direction);
        const right_cost = current_cost + 1000;
        const at_right = grid.read(right_position).?;
        position_offset = grid.get_position_offset(right_position).?;
        global_visit_entry = &global_visited[position_offset];
        position_visited_from_this_path = current_visited.get(position_offset) != null;
        position_visited_from_direction_at_cheaper_cost = global_visit_entry.hasCheaper(right_cost, right_direction);
        if (!position_visited_from_this_path and !position_visited_from_direction_at_cheaper_cost and at_right != WALL) {
            turned_right = true;
            var right_path = cheapest_path;
            if (moved_forward or turned_left) {
                free_current_visited_copy = false;
                // Create a new path for this branch
                const new_path = MapPath{ .visited = current_visited, .cost = current_cost, .current = current_head, .direction = right_direction, .disqualified = false };
                paths.append(new_path) catch unreachable;
                right_path = &paths.items[paths.items.len - 1];
            }
            right_path.direction = right_direction;
            right_path.cost = right_cost;
        }

        if (!moved_forward and !turned_left and !turned_right) {
            cheapest_path.disqualified = true;
        }

        if (free_current_visited_copy) {
            current_visited.deinit();
        }
    }

    var unique_tiles = std.AutoHashMap(u64, void).init(std.heap.page_allocator);
    defer unique_tiles.deinit();
    for (paths.items) |*path| {
        if (!path.optimal) {
            continue;
        }
        var path_iterator = path.visited.iterator();
        while (path_iterator.next()) |entry| {
            unique_tiles.put(entry.key_ptr.*, {}) catch unreachable;
        }
    }

    for (paths.items) |*path| {
        path.visited.deinit();
    }

    // Add 1 for the END tile
    return unique_tiles.count() + 1;
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
    try std.testing.expectEqual(11048, result);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    try std.testing.expectEqual(127520, result);
}

test "part 2 small" {
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_two(&reader);
    try std.testing.expectEqual(64, result);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    try std.testing.expectEqual(1, result);
}
