const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const benchmark = @import("utils/benchmark.zig");
const Bitfield = @import("utils/bitfield.zig").Bitfield;

const day = 14;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("../data/day{d}_small.txt", .{day});

pub fn part_one(reader: *Reader) u64 {
    const width: i32 = 101;
    const height: i32 = 103;
    const steps = 100;

    var quadrant_counts: [4]u32 = std.mem.zeroes([4]u32);
    const width_halfway: i32 = (@divExact((width + 1), @as(i32, 2)) - 1);
    const height_halfway: i32 = (@divExact((height + 1), @as(i32, 2)) - 1);

    while (reader.search_next_int(i32)) |position_x| {
        const position_y = reader.search_next_int(i32).?;
        const velocity_x = reader.search_next_int(i32).?;
        const velocity_y = reader.search_next_int(i32).?;

        const x_position_after_steps = @mod((position_x + (velocity_x * steps)), width);
        const y_position_after_steps = @mod((position_y + (velocity_y * steps)), height);

        if (x_position_after_steps == width_halfway or y_position_after_steps == height_halfway) {
            continue;
        }

        var quadrant_index: usize = 0;
        if (x_position_after_steps > width_halfway) {
            quadrant_index += 1;
        }
        if (y_position_after_steps > height_halfway) {
            quadrant_index += 2;
        }
        quadrant_counts[quadrant_index] += 1;
    }

    return quadrant_counts[0] * quadrant_counts[1] * quadrant_counts[2] * quadrant_counts[3];
}

const Robot = struct {
    const Self = @This();
    x: i32,
    y: i32,
    velocity_x: i32,
    velocity_y: i32,
    pub fn step(self: *Self, width: i32, height: i32) void {
        self.x += self.velocity_x;
        self.x = @mod(self.x, width);
        self.y += self.velocity_y;
        self.y = @mod(self.y, height);
    }

    pub fn stepN(self: *Self, n: u32, width: i32, height: i32) void {
        self.x += self.velocity_x * @as(i32, @intCast(n));
        self.x = @mod(self.x, width);
        self.y += self.velocity_y * @as(i32, @intCast(n));
        self.y = @mod(self.y, height);
    }
};

fn print_map(map: *Bitfield(10403), width: comptime_int, height: comptime_int) void {
    var height_offset: u32 = 0;
    for (0..height) |_| {
        for (0..width) |x| {
            if (map.get(height_offset + x)) {
                std.debug.print("X", .{});
            } else {
                std.debug.print(" ", .{});
            }
        }
        height_offset += width;
        std.debug.print("\n", .{});
    }
}

pub fn part_two(reader: *Reader) u64 {
    const width: i32 = 101;
    const height: i32 = 103;

    var robots = std.ArrayList(Robot).init(std.heap.page_allocator);
    defer robots.deinit();

    while (reader.search_next_int(i32)) |position_x| {
        var robot: Robot = undefined;
        robot.x = position_x;
        robot.y = reader.search_next_int(i32).?;
        robot.velocity_x = reader.search_next_int(i32).?;
        robot.velocity_y = reader.search_next_int(i32).?;

        robots.append(robot) catch unreachable;
    }

    var map = Bitfield(width * height).init();
    var step: u32 = 0;

    // Detect the period of the *almost* christmas tree patterns
    var first: i32 = -1;
    var second: i32 = -1;
    while (second == -1) {
        map.clear();
        for (robots.items) |*robot| {
            robot.step(width, height);
            const offset = robot.x + robot.y * width;
            map.set(@as(u64, @intCast(offset)));
        }
        step += 1;

        var high_bitcounts: u32 = 0;
        for (map.data) |value| {
            var bit_count: u8 = 0;
            for (0..8) |bit| {
                if ((value & (@as(u8, 1) << @intCast(bit))) > 0) {
                    bit_count += 1;
                }
            }
            if (bit_count > 3) {
                high_bitcounts += 1;
            }
        }

        if (high_bitcounts >= 8) {
            if (first == -1) {
                first = @as(i32, @intCast(step));
            } else {
                second = @as(i32, @intCast(step));
            }
        }
    }

    const period = @as(u32, @intCast(second - first));

    while (true) {
        map.clear();
        for (robots.items) |*robot| {
            robot.stepN(period, width, height);
            const offset = robot.x + robot.y * width;
            if (map.setAndGetByte(@as(u64, @intCast(offset))) == 0xff) {
                return step + period;
            }
        }

        step += period;
    }

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

// test "part 1 small" {
//     var reader = Reader.from_comptime_path(small_data_path);
//     const result = part_one(&reader, 11, 7);
//     std.debug.print("\nResult: {}\n", .{result});
//     try std.testing.expect(result == 12);
// }

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 236628054);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    // 7585 is too high
    try std.testing.expect(result == 7584);
}
