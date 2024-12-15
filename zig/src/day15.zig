const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const benchmark = @import("utils/benchmark.zig");

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
    wide_box,
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
            .robot => return '@',
        }
    }
};

const Warehouse = struct {
    const Self = @This();
    width: u32,
    height: u32,
    tiles: std.ArrayList(Tile),
    robot_index: u32,

    pub fn init(reader: *Reader) Self {
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
                    width += 1;
                }
                const tile = Tile.from_char(next);
                if (tile == Tile.robot) {
                    robot_index = @as(u32, @intCast(tiles.items.len));
                }
                tiles.append(tile) catch unreachable;
            }
        }

        return Self{ .width = width, .height = height, .robot_index = robot_index, .tiles = tiles };
    }

    pub fn move_robot(self: *Self, direction: u8) void {
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
            if (self.tiles.items[idx] == Tile.box) {
                const y = idx / self.width;
                const x = idx % self.width;
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
    }
};

pub fn part_one(reader: *Reader) u64 {
    // read in map
    var warehouse = Warehouse.init(reader);
    defer warehouse.deinit();

    // warehouse.print();

    while (reader.next_char()) |next_char| {
        if (next_char == '\n') {
            continue;
        }
        warehouse.move_robot(next_char);
        // warehouse.print();
    }

    return warehouse.sum_box_gps();
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
    std.debug.print("\nPart 1 Small:\n", .{});
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 10092);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1371036);
}

test "part 2 small" {
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 1);
}
