const std = @import("std");
const Reader = @import("reader.zig").Reader;
const Grid = @import("grid.zig").Grid;
const Position = @import("grid.zig").Position;
const Direction = @import("grid.zig").Direction;
const benchmark = @import("benchmark.zig");

const day = 6;
const data_path = std.fmt.comptimePrint("./data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("./data/day{d}_small.txt", .{day});

const BitfieldMap = struct {
    data: [130][3]u64,
    const Self = @This();

    pub fn init() Self {
        return Self{ .data = std.mem.zeroes([130][3]u64) };
    }

    pub fn set(self: *Self, position: Position) void {
        const y = @as(usize, @intCast(position.y));
        const x: usize = @as(usize, @intCast(@divTrunc(position.x, 64)));
        self.data[y][x] |= @as(u64, 1) << @intCast(@mod(position.x, 64));
    }

    pub fn read(self: *Self, position: Position) bool {
        const y = @as(usize, @intCast(position.y));
        const x: usize = @as(usize, @intCast(@divTrunc(position.x, 64)));
        return (self.data[y][x] & (@as(u64, 1) << @intCast(@mod(position.x, 64)))) > 0;
    }
};

const Bitfield = struct {
    data: []u8,
    const Self = @This();

    pub fn init(size: usize) Self {
        const num_bytes = @divFloor(size, @sizeOf(u8)) + 1;
        const data = std.heap.page_allocator.alloc(u8, num_bytes) catch unreachable;

        return Self{ .data = data };
    }

    pub fn set(self: *Self, position: u64) void {
        const byte_offset = @divFloor(position, @sizeOf(u8));
        const bit_offset = @mod(position, @sizeOf(u8));

        self.data[byte_offset] |= @as(u8, 1) << @intCast(bit_offset);
    }

    pub fn get(self: *Self, position: u64) bool {
        const byte_offset = @divFloor(position, @sizeOf(u8));
        const bit_offset = @mod(position, @sizeOf(u8));
        return (self.data[byte_offset] & @as(u8, 1) << @intCast(bit_offset)) > 0;
    }

    pub fn deinit(self: *Self) void {
        std.heap.page_allocator.free(self.data);
    }
};

const DirectionMap = struct {
    data: [130][130]?Direction,
    const Self = @This();

    pub fn init() Self {
        var new = Self{ .data = undefined };
        new.reset();
        return new;
    }

    pub fn set(self: *Self, position: Position, direction: Direction) void {
        const x = @as(usize, @intCast(position.x));
        const y = @as(usize, @intCast(position.y));
        self.data[y][x] = direction;
    }

    pub fn read(self: *Self, position: Position) ?Direction {
        const x = @as(usize, @intCast(position.x));
        const y = @as(usize, @intCast(position.y));
        return self.data[y][x];
    }

    pub fn reset(self: *Self) void {
        for (0..130) |i| {
            for (0..130) |j| {
                self.data[i][j] = null;
            }
        }
    }
};

pub fn part_one(reader: *Reader) u64 {
    // Find guard initial position
    const position_offset = reader.seek_to_next_substr("^").?;
    var grid = Grid.init(reader.data);
    var guard_position = grid.get_position_from_offset(position_offset).?;
    var map = BitfieldMap.init();
    map.set(guard_position);
    var sum: u64 = 1;
    var direction = Direction.north;
    while (true) {
        const next_position = Position.from_step(guard_position, direction);
        const at_position = grid.read(next_position);
        if (at_position) |char| {
            if (char == '#') {
                direction.turn_90_degrees();
            } else {
                guard_position = next_position;
                if (!map.read(next_position)) {
                    sum += 1;
                    map.set(next_position);
                }
            }
        } else {
            break;
        }
    }

    return sum;
}

pub fn part_two(reader: *Reader) u64 {
    // Find guard initial position
    const position_offset = reader.seek_to_next_substr("^").?;
    var grid = Grid.init(reader.data);
    const guard_initial_position = grid.get_position_from_offset(position_offset).?;
    var map = DirectionMap.init();
    var direction = Direction.north;

    var sum: u64 = 0;

    var obstacle_offset: u64 = 0;
    var obstacle_position: Position = undefined;

    var obstacle_position_bitfield = Bitfield.init(reader.data.len);
    defer obstacle_position_bitfield.deinit();

    obstacle_position_bitfield.set(grid.get_position_offset(guard_initial_position).?);

    while (true) {
        // std.debug.print("--------------------\n", .{});
        var guard_position = guard_initial_position;
        direction = Direction.north;
        map.reset();
        map.set(guard_position, direction);

        var path_length: u32 = 0;
        var obstical_set = false;
        // std.debug.print("[{d}] Starting at position: {any}\n", .{ obstacle_offset, guard_position });
        while (true) {
            const next_position = Position.from_step(guard_position, direction);
            const at_position = grid.read(next_position);
            if (at_position) |char| {
                if (char != '#' and path_length >= obstacle_offset and !obstical_set and obstacle_position_bitfield.get(grid.get_position_offset(next_position).?) == false) {
                    obstacle_position = next_position;
                    obstacle_position_bitfield.set(grid.get_position_offset(next_position).?);
                    obstical_set = true;
                    // std.debug.print(" * Setting obstacle at {any}\n", .{obstacle_position});
                }
                const current_position_is_obstacle = (obstical_set and std.meta.eql(obstacle_position, next_position));
                if (char == '#' or current_position_is_obstacle) {
                    direction.turn_90_degrees();
                    // std.debug.print("Found obstical at: {any}\n", .{next_position});
                    // std.debug.print("Changing direction to: {any}\n", .{direction});
                } else {
                    guard_position = next_position;
                    // std.debug.print("moving to position: {any}\n", .{next_position});
                    if (map.read(next_position)) |map_result| {
                        if (map_result == direction) {
                            // std.debug.print("Found Loop!\n", .{});
                            sum += 1;
                            break;
                        }
                    } else {
                        path_length += 1;
                        map.set(next_position, direction);
                    }
                }
            } else {
                // std.debug.print("No Loop!\n", .{});
                break;
            }
        }
        obstacle_offset += 1;
        if (obstical_set == false) {
            // std.debug.print("No Obstacle Set!\n", .{});
            break;
        }
    }

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
    try std.testing.expect(result == 41);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 5312);
}

test "part 2 small" {
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 6);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1748);
}
