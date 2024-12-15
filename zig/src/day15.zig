const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const benchmark = @import("utils/benchmark.zig");
const Stack = @import("utils/stack.zig").Stack;

const day = 15;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("../data/day{d}_small.txt", .{day});

const UP: u8 = '^';
const DOWN: u8 = 'v';
const LEFT: u8 = '<';
const RIGHT: u8 = '>';

const Tile = enum {
    const Self = @This();
    wall,
    empty,
    box,
    box_left,
    box_right,
    robot,

    pub fn from_char(char: u8) Self {
        switch (char) {
            '#' => return Self.wall,
            '.' => return Self.empty,
            'O' => return Self.box,
            '@' => return Self.robot,
            else => @panic("Could not create Tile from char"),
        }
    }

    pub fn to_char(self: *Self) u8 {
        switch (self.*) {
            .wall => return '#',
            .empty => return '.',
            .box => return 'O',
            .box_left => return '[',
            .box_right => return ']',
            .robot => return '@',
        }
    }
};

const TileMovePlan = struct { tile: Tile, old_position: u32, new_position: u32 };

const Warehouse = struct {
    const Self = @This();
    const move_stack_size = 12;
    width: u32,
    height: u32,
    tiles: std.ArrayList(Tile),
    robot_index: u32,
    wide: bool,
    move_plan: std.ArrayList(TileMovePlan),
    move_stack: Stack(u32, move_stack_size),
    pub fn init(reader: *Reader, wide: bool) Self {
        var tiles = std.ArrayList(Tile).init(std.heap.page_allocator);
        var width: u32 = 0;
        var height: u32 = 0;
        var robot_index: u32 = 0;
        while (true) {
            const next = reader.next_char().?;
            if (next == '\n') {
                if (reader.peek_previous_char().? == '\n') {
                    break;
                }
                height += 1;
            } else {
                if (height == 0) {
                    width += 1 + @as(u8, @intFromBool(wide));
                }
                const tile = Tile.from_char(next);
                switch (tile) {
                    .wall, .empty => {
                        tiles.append(tile) catch unreachable;
                        if (wide) {
                            tiles.append(tile) catch unreachable;
                        }
                    },
                    .box => {
                        if (wide) {
                            tiles.append(Tile.box_left) catch unreachable;
                            tiles.append(Tile.box_right) catch unreachable;
                        } else {
                            tiles.append(tile) catch unreachable;
                        }
                    },
                    .robot => {
                        robot_index = @as(u32, @intCast(tiles.items.len));
                        tiles.append(tile) catch unreachable;
                        if (wide) {
                            tiles.append(Tile.empty) catch unreachable;
                        }
                    },
                    else => @panic("unexpected tile"),
                }
            }
        }

        return Self{ .move_plan = std.ArrayList(TileMovePlan).init(std.heap.page_allocator), .move_stack = Stack(u32, move_stack_size).init(), .width = width, .wide = wide, .height = height, .robot_index = robot_index, .tiles = tiles };
    }

    fn move_robot_wide(self: *Self, direction: u8) void {
        const robot_x: u32 = self.robot_index % self.width;
        const robot_y: u32 = self.robot_index / self.width;

        if (direction == UP) {
            if (robot_y == 1) {
                return;
            }
            self.move_plan.clearRetainingCapacity();
            self.move_stack.clear();
            self.move_stack.push(self.robot_index) catch unreachable;
            while (self.move_stack.pop()) |index_to_move| {
                const tile_to_move = self.tiles.items[index_to_move];
                const next_tile_index = index_to_move - self.width;
                const next_tile = self.tiles.items[next_tile_index];
                self.move_plan.append(.{ .old_position = index_to_move, .new_position = next_tile_index, .tile = tile_to_move }) catch unreachable;
                if (next_tile == Tile.wall) {
                    return;
                } else if (next_tile == Tile.box_right) {
                    // Add the left and right sides of the box to the move stack
                    self.move_stack.push(next_tile_index) catch unreachable;
                    self.move_stack.push(next_tile_index - 1) catch unreachable;
                } else if (next_tile == Tile.box_left) {
                    // Add the left and right sides of the box to the move stack
                    self.move_stack.push(next_tile_index) catch unreachable;
                    self.move_stack.push(next_tile_index + 1) catch unreachable;
                }
            }

            // clear tiles
            for (self.move_plan.items) |plan| {
                self.tiles.items[plan.old_position] = Tile.empty;
            }
            // move tiles
            for (self.move_plan.items) |plan| {
                self.tiles.items[plan.new_position] = plan.tile;
            }

            self.robot_index -= self.width;
        } else if (direction == DOWN) {
            if (robot_y == self.height - 1) {
                return;
            }
            self.move_plan.clearRetainingCapacity();
            self.move_stack.clear();
            self.move_stack.push(self.robot_index) catch unreachable;
            while (self.move_stack.pop()) |index_to_move| {
                // check if space above is free
                const tile_to_move = self.tiles.items[index_to_move];
                const next_tile_index = index_to_move + self.width;
                const next_tile = self.tiles.items[next_tile_index];
                self.move_plan.append(.{ .old_position = index_to_move, .new_position = next_tile_index, .tile = tile_to_move }) catch unreachable;
                if (next_tile == Tile.wall) {
                    return;
                } else if (next_tile == Tile.box_right) {
                    // Add the left and right sides of the box to the move stack
                    self.move_stack.push(next_tile_index) catch unreachable;
                    self.move_stack.push(next_tile_index - 1) catch unreachable;
                } else if (next_tile == Tile.box_left) {
                    // Add the left and right sides of the box to the move stack
                    self.move_stack.push(next_tile_index) catch unreachable;
                    self.move_stack.push(next_tile_index + 1) catch unreachable;
                }
            }

            // clear tiles
            for (self.move_plan.items) |plan| {
                self.tiles.items[plan.old_position] = Tile.empty;
            }
            // move tiles
            for (self.move_plan.items) |plan| {
                self.tiles.items[plan.new_position] = plan.tile;
            }

            self.robot_index += self.width;
        } else if (direction == LEFT) {
            if (robot_x == 2) {
                return;
            }

            var steps: usize = 1;
            var found_box: bool = false;
            while (true) {
                const next_tile = &self.tiles.items[self.robot_index - steps];
                if (next_tile.* == Tile.box_right) {
                    found_box = true;
                } else if (next_tile.* == Tile.wall) {
                    return;
                } else if (next_tile.* == Tile.empty) {
                    if (found_box) {
                        for (1..steps + 1) |step| {
                            if (step % 2 == 0) {
                                self.tiles.items[self.robot_index - step] = Tile.box_right;
                            } else {
                                self.tiles.items[self.robot_index - step] = Tile.box_left;
                            }
                        }
                    }
                    break;
                }
                steps += 1;
            }

            self.tiles.items[self.robot_index] = Tile.empty;
            self.robot_index -= 1;
            self.tiles.items[self.robot_index] = Tile.robot;
        } else if (direction == RIGHT) {
            if (robot_x == self.width - 3) {
                return;
            }

            var steps: usize = 1;
            var found_box: bool = false;
            while (true) {
                const next_tile = &self.tiles.items[self.robot_index + steps];
                if (next_tile.* == Tile.box_left) {
                    found_box = true;
                    steps += 1;
                } else if (next_tile.* == Tile.wall) {
                    return;
                } else if (next_tile.* == Tile.empty) {
                    if (found_box) {
                        for (1..steps + 1) |step| {
                            if (step % 2 == 0) {
                                self.tiles.items[self.robot_index + step] = Tile.box_left;
                            } else {
                                self.tiles.items[self.robot_index + step] = Tile.box_right;
                            }
                        }
                    }
                    break;
                }
                steps += 1;
            }

            self.tiles.items[self.robot_index] = Tile.empty;
            self.robot_index += 1;
            self.tiles.items[self.robot_index] = Tile.robot;
        }
    }

    pub fn move_robot(self: *Self, direction: u8) void {
        if (self.wide) {
            return self.move_robot_wide(direction);
        }
        // std.debug.print("Moving Robot: {c}\n", .{direction});

        const robot_x: u32 = self.robot_index % self.width;
        const robot_y: u32 = self.robot_index / self.width;

        if (direction == UP) {
            if (robot_y == 1) {
                return;
            }

            var steps: usize = 1;
            var found_box: bool = false;
            while (true) {
                const next_down_tile = &self.tiles.items[self.robot_index - self.width * steps];
                if (next_down_tile.* == Tile.box) {
                    found_box = true;
                } else if (next_down_tile.* == Tile.wall) {
                    return;
                } else if (next_down_tile.* == Tile.empty) {
                    if (found_box) {
                        next_down_tile.* = Tile.box;
                    }
                    break;
                }
                steps += 1;
            }

            self.tiles.items[self.robot_index] = Tile.empty;
            self.robot_index -= self.width;
            self.tiles.items[self.robot_index] = Tile.robot;
        } else if (direction == DOWN) {
            if (robot_y == self.height - 2) {
                return;
            }

            var steps: usize = 1;
            var found_box: bool = false;
            while (true) {
                const next_down_tile = &self.tiles.items[self.robot_index + self.width * steps];
                if (next_down_tile.* == Tile.box) {
                    found_box = true;
                } else if (next_down_tile.* == Tile.wall) {
                    return;
                } else if (next_down_tile.* == Tile.empty) {
                    if (found_box) {
                        next_down_tile.* = Tile.box;
                    }
                    break;
                }
                steps += 1;
            }

            self.tiles.items[self.robot_index] = Tile.empty;
            self.robot_index += self.width;
            self.tiles.items[self.robot_index] = Tile.robot;
        } else if (direction == LEFT) {
            if (robot_x == 1) {
                return;
            }

            var steps: usize = 1;
            var found_box: bool = false;
            while (true) {
                const next_tile = &self.tiles.items[self.robot_index - steps];
                if (next_tile.* == Tile.box) {
                    found_box = true;
                } else if (next_tile.* == Tile.wall) {
                    return;
                } else if (next_tile.* == Tile.empty) {
                    if (found_box) {
                        next_tile.* = Tile.box;
                    }
                    break;
                }
                steps += 1;
            }

            self.tiles.items[self.robot_index] = Tile.empty;
            self.robot_index -= 1;
            self.tiles.items[self.robot_index] = Tile.robot;
        } else { // direction == RIGHT
            if (robot_x == self.width - 2) {
                return;
            }

            var steps: usize = 1;
            var found_box: bool = false;
            while (true) {
                const next_tile = &self.tiles.items[self.robot_index + steps];
                if (next_tile.* == Tile.box) {
                    found_box = true;
                } else if (next_tile.* == Tile.wall) {
                    return;
                } else if (next_tile.* == Tile.empty) {
                    if (found_box) {
                        next_tile.* = Tile.box;
                    }
                    break;
                }
                steps += 1;
            }

            self.tiles.items[self.robot_index] = Tile.empty;
            self.robot_index += 1;
            self.tiles.items[self.robot_index] = Tile.robot;
        }
    }

    pub fn sum_box_gps(self: *Self) u64 {
        var sum: u64 = 0;

        for (0..self.width * self.height) |idx| {
            const y = idx / self.width;
            const x = idx % self.width;
            if (self.tiles.items[idx] == Tile.box) {
                sum += y * 100 + x;
            } else if (self.tiles.items[idx] == Tile.box_left) {
                sum += y * 100 + x;
            }
        }

        return sum;
    }

    pub fn print(self: *const Self) void {
        for (0..self.width * self.height) |iter| {
            std.debug.print("{c}", .{self.tiles.items[iter].to_char()});
            if (iter > 0 and @mod(iter + 1, self.width) == 0) {
                std.debug.print("\n", .{});
            }
        }
    }

    pub fn deinit(self: *Self) void {
        self.tiles.deinit();
        self.move_plan.deinit();
    }
};

pub fn part_one(reader: *Reader) u64 {
    // read in map
    var warehouse = Warehouse.init(reader, false);
    defer warehouse.deinit();

    while (reader.next_char()) |next_char| {
        if (next_char == '\n') {
            continue;
        }
        warehouse.move_robot(next_char);
    }

    return warehouse.sum_box_gps();
}

pub fn part_two(reader: *Reader) u64 {
    // read in map
    var warehouse = Warehouse.init(reader, true);
    defer warehouse.deinit();

    var count: u32 = 0;

    while (reader.next_char()) |next_char| {
        if (next_char == '\n') {
            continue;
        }
        warehouse.move_robot(next_char);
        count += 1;
    }

    return warehouse.sum_box_gps();
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
    try std.testing.expectEqual(result, 10092);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    try std.testing.expectEqual(result, 1371036);
}

test "part 2 small" {
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_two(&reader);
    try std.testing.expectEqual(result, 9021);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    try std.testing.expectEqual(result, 1392847);
}
