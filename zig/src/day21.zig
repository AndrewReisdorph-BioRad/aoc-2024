const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const Grid = @import("utils/grid.zig").Grid;
const Position = @import("utils/grid.zig").Position;

const benchmark = @import("utils/benchmark.zig");
const Stack = @import("utils/stack.zig").Stack;

const day = 21;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});

const UP = '^';
const DOWN = 'v';
const LEFT = '<';
const RIGHT = '>';
const ACTIVATE = 'A';

const Code = [4]u8;

const DPadKeyCode = enum(u3) {
    const Self = @This();
    up = 1,
    down = 2,
    left = 3,
    right = 4,
    activate = 5,
    pub fn from_char(char: u8) Self {
        return switch (char) {
            UP => .up,
            DOWN => .down,
            LEFT => .left,
            RIGHT => .right,
            ACTIVATE => .activate,
            else => unreachable,
        };
    }
    pub fn row(self: *const Self) u8 {
        if (self.* == .up or self.* == .activate) {
            return 0;
        }
        return 1;
    }
    pub fn column(self: *const Self) u8 {
        return switch (self.*) {
            .left => 0,
            .up, .down => 1,
            else => 2,
        };
    }
};

const KeypadPaths = struct {
    const Self = @This();
    paths: [2][5]DPadKeyCode = undefined,
    num_paths: u8 = 0,
    length: u8 = 0,
};

const DPad = struct {
    const Self = @This();
    current: DPadKeyCode = .activate,
    pub fn calc_paths_to_key(self: *Self, key: DPadKeyCode) KeypadPaths {
        // Four options exists:
        // 0. Key is the current key
        // 1. Key is on same row/column and we only need to move in one direction
        // 2. Move vertically and then horizontally
        // 3. Move horizontally and then vertically
        var paths = KeypadPaths{};

        if (key == self.current) {
            return paths;
        }

        const current_row = self.current.row();
        const current_col = self.current.column();
        const key_row = key.row();
        const key_col = key.column();

        const horizontal_direction = if (current_col > key_col) DPadKeyCode.left else DPadKeyCode.right;
        const vertical_direction = if (current_row > key_row) DPadKeyCode.up else DPadKeyCode.down;
        const horizontal_distance = @as(u8, @abs(@as(i8, @intCast(current_col)) - @as(i8, @intCast(key_col))));
        const vertical_distance = @as(u8, @abs(@as(i8, @intCast(current_row)) - @as(i8, @intCast(key_row))));

        paths.length = horizontal_distance + vertical_distance;

        if (current_row == key_row) {
            paths.num_paths = 1;
            for (0..horizontal_distance) |i| {
                paths.paths[0][i] = horizontal_direction;
            }
        } else if (current_col == key_col) {
            paths.num_paths = 1;
            for (0..vertical_distance) |i| {
                paths.paths[0][i] = vertical_direction;
            }
        } else {
            paths.num_paths = 2;
            switch (self.current) {
                .up => {
                    switch (key) {
                        .left => {
                            paths.num_paths = 1;
                            paths.paths[0][0] = .down;
                            paths.paths[0][1] = .left;
                        },
                        .right => {
                            paths.paths[0][0] = .down;
                            paths.paths[0][1] = .right;

                            paths.paths[1][0] = .right;
                            paths.paths[1][1] = .down;
                        },
                        else => unreachable,
                    }
                },
                .activate => {
                    switch (key) {
                        .left => {
                            paths.paths[0][0] = .down;
                            paths.paths[0][1] = .left;
                            paths.paths[0][2] = .left;

                            paths.paths[1][0] = .left;
                            paths.paths[1][1] = .down;
                            paths.paths[1][2] = .left;
                        },
                        .down => {
                            paths.paths[0][0] = .down;
                            paths.paths[0][1] = .left;

                            paths.paths[1][0] = .left;
                            paths.paths[1][1] = .down;
                        },
                        else => unreachable,
                    }
                },
                .left => {
                    switch (key) {
                        .up => {
                            paths.num_paths = 1;
                            paths.paths[0][0] = .right;
                            paths.paths[0][1] = .up;
                        },
                        .activate => {
                            paths.paths[0][0] = .right;
                            paths.paths[0][1] = .up;
                            paths.paths[0][2] = .right;

                            paths.paths[1][0] = .right;
                            paths.paths[1][1] = .right;
                            paths.paths[1][2] = .up;
                        },
                        else => unreachable,
                    }
                },
                .down => {
                    switch (key) {
                        .activate => {
                            paths.paths[0][0] = .right;
                            paths.paths[0][1] = .up;

                            paths.paths[1][0] = .up;
                            paths.paths[1][1] = .right;
                        },
                        else => unreachable,
                    }
                },
                .right => {
                    switch (key) {
                        .up => {
                            paths.paths[0][0] = .left;
                            paths.paths[0][1] = .up;

                            paths.paths[1][0] = .up;
                            paths.paths[1][1] = .left;
                        },
                        else => unreachable,
                    }
                },
            }
        }

        return paths;
    }
    pub fn calc_cost_to_press_key(self: *Self, key: DPadKeyCode, id: u8, dpads: []DPad) u64 {
        const old_current = self.current;
        if (id == 0) {
            self.current = key;
            return @as(u64, switch (old_current) {
                .up => switch (key) {
                    .up => 0,
                    .down => 1,
                    .left => 2,
                    .right => 2,
                    .activate => 1,
                },
                .down => switch (key) {
                    .up => 1,
                    .down => 0,
                    .left => 1,
                    .right => 1,
                    .activate => 2,
                },
                .left => switch (key) {
                    .up => 2,
                    .down => 1,
                    .left => 0,
                    .right => 2,
                    .activate => 3,
                },
                .right => switch (key) {
                    .up => 2,
                    .down => 1,
                    .left => 2,
                    .right => 0,
                    .activate => 1,
                },
                .activate => switch (key) {
                    .up => 1,
                    .down => 2,
                    .left => 3,
                    .right => 1,
                    .activate => 0,
                },
            }) + 1;
        } else {
            const paths = self.calc_paths_to_key(key);
            self.current = key;

            if (paths.num_paths > 1) {
                // Create copy of current D-Pad state
                var dpads_copy: [25]DPad = undefined;
                for (0..dpads.len) |i| {
                    dpads_copy[i] = dpads[i];
                }

                var first_path_total_cost: u64 = 0;
                for (paths.paths[0][0..paths.length]) |step| {
                    first_path_total_cost += dpads[id - 1].calc_cost_to_press_key(step, id - 1, dpads);
                }
                first_path_total_cost += dpads[id - 1].calc_cost_to_press_key(DPadKeyCode.activate, id - 1, dpads);

                var second_path_total_cost: u64 = 0;
                for (paths.paths[1][0..paths.length]) |step| {
                    second_path_total_cost += dpads_copy[id - 1].calc_cost_to_press_key(step, id - 1, &dpads_copy);
                }
                second_path_total_cost += dpads_copy[id - 1].calc_cost_to_press_key(DPadKeyCode.activate, id - 1, &dpads_copy);

                if (second_path_total_cost < first_path_total_cost) {
                    for (0..dpads.len) |i| {
                        dpads[i] = dpads_copy[i];
                    }
                    return second_path_total_cost;
                }
                return first_path_total_cost;
            } else {
                var first_path_total_cost: u64 = 0;
                for (paths.paths[0][0..paths.length]) |step| {
                    first_path_total_cost += dpads[id - 1].calc_cost_to_press_key(step, id - 1, dpads);
                }
                first_path_total_cost += dpads[id - 1].calc_cost_to_press_key(DPadKeyCode.activate, id - 1, dpads);

                return first_path_total_cost;
            }
        }
    }
};

const PathNode = struct { position: Position, cost: u64 };

const NumPad = struct {
    const Self = @This();
    inner: Grid = Grid.init(
        \\789
        \\456
        \\123
        \\X0A
    ),
    pos: Position = Position{ .x = 2, .y = 3 },
    pub fn get_key_column(key: u8) u8 {
        const key_mod_3 = (key - 48) % 3;
        if (key == 'A') {
            return 2;
        } else if (key == '0') {
            return 1;
        } else if (key_mod_3 == 0) {
            return 2;
        } else if (key_mod_3 == 2) {
            return 1;
        }
        return 0;
    }
    pub fn get_key_row(key: u8) u8 {
        if (key == 'A') {
            return 3;
        }
        if (key >= '7') {
            return 0;
        } else if (key >= '4') {
            return 1;
        } else if (key >= '1') {
            return 2;
        }
        return 3;
    }
    pub fn calc_paths_to_key(current: u8, key: u8) KeypadPaths {
        // Four options exists:
        // 0. Key is the current key
        // 1. Key is on same row/column and we only need to move in one direction
        // 2. Move vertically and then horizontally
        // 3. Move horizontally and then vertically
        var paths = KeypadPaths{};

        if (key == current) {
            return paths;
        }

        const key_column = Self.get_key_column(key);
        const key_row = Self.get_key_row(key);

        const current_column = Self.get_key_column(current);
        const current_row = Self.get_key_row(current);

        if (key_column == current_column) {
            const direction = if (key_row > current_row) DPadKeyCode.down else DPadKeyCode.up;
            paths.num_paths = 1;
            paths.length = @abs(@as(i8, @intCast(key_row)) - @as(i8, @intCast(current_row)));
            for (0..paths.length) |i| {
                paths.paths[0][i] = direction;
            }
            return paths;
        }

        if (key_row == current_row) {
            const direction = if (key_column > current_column) DPadKeyCode.right else DPadKeyCode.left;
            paths.num_paths = 1;
            paths.length = @abs(@as(i8, @intCast(key_column)) - @as(i8, @intCast(current_column)));
            for (0..paths.length) |i| {
                paths.paths[0][i] = direction;
            }
            return paths;
        }

        const vertical_direction = if (key_row > current_row) DPadKeyCode.down else DPadKeyCode.up;
        const horizontal_direction = if (key_column > current_column) DPadKeyCode.right else DPadKeyCode.left;
        const horizontal_distance = @abs(@as(i8, @intCast(key_column)) - @as(i8, @intCast(current_column)));
        const vertical_distance = @abs(@as(i8, @intCast(key_row)) - @as(i8, @intCast(current_row)));
        paths.length = horizontal_distance + vertical_distance;
        paths.num_paths = 2;

        if (current == 'A' and key_column == 0) {
            // The vertical-first case has no potential invalid moves
            for (0..vertical_distance) |i| {
                paths.paths[0][i] = vertical_direction;
            }
            for (vertical_distance..vertical_distance + horizontal_distance) |i| {
                paths.paths[0][i] = horizontal_direction;
            }

            // The horizontal case can only go as far as '0'
            paths.paths[1][0] = DPadKeyCode.left;
            paths.paths[1][1] = DPadKeyCode.up;
            paths.paths[1][2] = DPadKeyCode.left;
            for (3..3 + (vertical_distance - 1)) |i| {
                paths.paths[1][i] = vertical_direction;
            }
        } else if (current_column == 0 and (key == 'A' or key == '0')) {
            // The horizontal-first case has no potential invalid moves
            for (0..horizontal_distance) |i| {
                paths.paths[0][i] = horizontal_direction;
            }
            for (horizontal_distance..horizontal_distance + vertical_distance) |i| {
                paths.paths[0][i] = vertical_direction;
            }

            // The vertical-first case will run into a void so stop before you hit it
            for (0..(vertical_distance - 1)) |i| {
                paths.paths[1][i] = vertical_direction;
            }
            paths.paths[1][vertical_distance - 1] = DPadKeyCode.right;
            paths.paths[1][vertical_distance] = DPadKeyCode.down;
            for (vertical_distance + 1..vertical_distance + 1 + horizontal_distance) |i| {
                paths.paths[0][i] = horizontal_direction;
            }
        } else if (current == '0' and key_column == 0) {
            unreachable;
        } else {
            for (0..horizontal_distance) |i| {
                paths.paths[0][i] = horizontal_direction;
            }
            for (horizontal_distance..horizontal_distance + vertical_distance) |i| {
                paths.paths[0][i] = vertical_direction;
            }

            for (0..vertical_distance) |i| {
                paths.paths[1][i] = vertical_direction;
            }
            for (vertical_distance..vertical_distance + horizontal_distance) |i| {
                paths.paths[1][i] = horizontal_direction;
            }
        }

        return paths;
    }
};

fn State(num_dpads: comptime_int) type {
    return struct { dpads: [num_dpads]DPad = .{DPad{}} ** num_dpads, keypresses: u64 = 0 };
}

pub fn get_code_cost(code: Code, num_dpads: comptime_int, state: *State(num_dpads)) u64 {
    state.keypresses = 0;
    var super_paths = std.ArrayList(@TypeOf(state.*)).init(std.heap.page_allocator);
    var new_super_paths = std.ArrayList(@TypeOf(state.*)).init(std.heap.page_allocator);

    defer super_paths.deinit();
    defer new_super_paths.deinit();

    super_paths.append(state.*) catch unreachable;

    var last_numpad_key: u8 = 'A';
    for (code) |c| {
        const paths = NumPad.calc_paths_to_key(last_numpad_key, c);

        for (super_paths.items) |*super_path| {
            var second_path_state: @TypeOf(state.*) = super_path.*;

            for (paths.paths[0][0..paths.length]) |k| {
                super_path.keypresses += super_path.dpads[num_dpads - 1].calc_cost_to_press_key(k, @as(u8, @intCast(num_dpads - 1)), &super_path.dpads);
            }
            super_path.keypresses += super_path.dpads[num_dpads - 1].calc_cost_to_press_key(DPadKeyCode.activate, @as(u8, @intCast(num_dpads - 1)), &super_path.dpads);

            if (paths.num_paths > 1) {
                for (paths.paths[1][0..paths.length]) |k| {
                    second_path_state.keypresses += second_path_state.dpads[num_dpads - 1].calc_cost_to_press_key(k, @as(u8, @intCast(num_dpads - 1)), &second_path_state.dpads);
                }
                second_path_state.keypresses += second_path_state.dpads[num_dpads - 1].calc_cost_to_press_key(DPadKeyCode.activate, @as(u8, @intCast(num_dpads - 1)), &second_path_state.dpads);

                new_super_paths.append(second_path_state) catch unreachable;
            }
        }

        super_paths.appendSlice(new_super_paths.items) catch unreachable;
        new_super_paths.clearRetainingCapacity();

        last_numpad_key = c;
    }

    var cheapest: u64 = std.math.maxInt(u64);
    var cheapest_state_ptr = &super_paths.items[0];
    for (super_paths.items) |*super_path| {
        cheapest = @min(super_path.keypresses, cheapest);
        cheapest_state_ptr = super_path;
    }

    if (state != cheapest_state_ptr) {
        state.* = cheapest_state_ptr.*;
    }

    return cheapest;
}

const CACHE_ENABLED = true;

const StepLookup = struct {
    const Self = @This();
    map: std.AutoHashMap(u128, u64),
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .map = std.AutoHashMap(u128, u64).init(allocator) };
    }
    pub fn deinit(self: *Self) void {
        self.map.deinit();
    }
    pub fn calc_key(dpads: []DPad, step: u8) u128 {
        var key: u128 = 0;
        for (dpads) |dpad| {
            const next_key_bits: u128 = switch (dpad.current_key()) {
                .up => 1,
                .left => 2,
                .down => 3,
                .right => 4,
                .activate => 5,
            };
            key = (key << 3) | next_key_bits;
        }
        key = (key << 3) | @as(u128, switch (step) {
            '^' => 1,
            '<' => 2,
            'v' => 3,
            '>' => 4,
            'A' => 5,
            else => unreachable,
        });
        return key;
    }
    pub fn get(self: *Self, key: u128) ?u64 {
        return self.map.get(key);
    }
    pub fn put(self: *Self, key: u128, value: u64) void {
        self.map.put(key, value) catch unreachable;
    }
};

//     pub fn move_to_and_activate_key(self: *Self, key: u8, ship: anytype, lookup: *StepLookup) void {
//         std.debug.print("DPad[{d}] moving from {c} to key: {c}  ---- {d}\n", .{ self.id, self.current_key(), key, ship.dpads[0].key_presses });

//         const lookup_key = StepLookup.calc_key(ship.dpads[0 .. self.id + 1], key);

//         if (CACHE_ENABLED) {
//             if (lookup.get(lookup_key)) |key_presses| {
//                 // Subtract one because we call `.push` later
//                 ship.dpads[0].key_presses += key_presses - 1;
//                 std.debug.print("Cached: 0x{X} --> {d} -> {d}", .{ lookup_key, key_presses, ship.dpads[0].key_presses });
//                 self.current_key_idx = @as(u8, switch (key) {
//                     '^' => UP_IDX,
//                     '<' => LEFT_IDX,
//                     'v' => DOWN_IDX,
//                     '>' => RIGHT_IDX,
//                     'A' => ACTIVATE_IDX,
//                     else => unreachable,
//                 });
//                 std.debug.print("DPad[{d}] skipping to key: {c}\n", .{ self.id, key });
//                 for (0..self.id) |i| {
//                     ship.dpads[i].current_key_idx = ACTIVATE_IDX;
//                 }
//                 ship.dpads[0].push(ship);
//                 return;
//             }
//         }

//         const starting_key_presses = ship.dpads[0].key_presses;

//         while (self.current_key() != key) {
//             const step = self.calc_step_toward_key(key);
//             if (self.id == 0) {
//                 self.move_direction(step);
//             } else {
//                 //std.debug.print("DPad[{d}] needs DPad[{d}] to move to key: {c}\n", .{ self.id, self.id - 1, step });
//                 ship.dpads[self.id - 1].move_to_and_activate_key(step, ship, lookup);
//             }
//         }
//         //std.debug.print("DPad[{d}] is on target key: {c} \n", .{ self.id, self.current_key() });

//         if (self.id == 0) {
//             self.push(ship);
//         } else {
//             ship.dpads[self.id - 1].move_to_and_activate_key('A', ship, lookup);
//         }

//         const total_key_presses = ship.dpads[0].key_presses - starting_key_presses;
//         lookup.put(lookup_key, total_key_presses);
//     }

pub fn get_codes(reader: *Reader) [5]Code {
    var codes = std.mem.zeroes([5]Code);
    var code_idx: usize = 0;
    var digit_idx: usize = 0;
    while (reader.next_char()) |char| {
        if (char == '\n') {
            code_idx += 1;
            digit_idx = 0;
        } else {
            codes[code_idx][digit_idx] = char;
            digit_idx += 1;
        }
    }
    return codes;
}

pub fn part_one(reader: *Reader) u64 {
    var sum: u64 = 0;
    const codes = get_codes(reader);
    const num_dpads = 2;
    var state = State(num_dpads){};
    // var lookup = StepLookup.init(std.heap.page_allocator);
    // defer lookup.deinit();
    for (codes) |code| {
        const button_presses = get_code_cost(code, num_dpads, &state);
        const numeric_value = std.fmt.parseInt(u64, code[0..3], 10) catch unreachable;
        std.debug.print("\n=========================\nPresses: {d} Code: {d}\n=========================\n", .{ button_presses, numeric_value });

        sum += button_presses * numeric_value;
    }

    return sum;
}

pub fn part_two(reader: *Reader) u64 {
    _ = reader;
    // var sum: u64 = 0;
    // const codes = get_codes(reader);
    // var dpads: [25]DPad = .{DPad{}} ** 25;

    // // var lookup = StepLookup.init(std.heap.page_allocator);
    // // defer lookup.deinit();
    // for (codes) |code| {
    //     const button_presses = get_code_cost(code, &dpads);
    //     const numeric_value = std.fmt.parseInt(u64, code[0..3], 10) catch unreachable;
    //     std.debug.print("\n=========================\nPresses: {d} Code: {d}\n=========================\n", .{ button_presses, numeric_value });

    //     sum += button_presses * numeric_value;
    // }

    // return sum;
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
        \\029A
        \\980A
        \\179A
        \\456A
        \\379A
        \\
    );
    const result = part_one(&reader);
    try std.testing.expectEqual(126384, result);
}

// ========================================
// Benchmarking: Day 21 Part 1
// Warming up... 5 iterations --> 622 µs
// Measuring... 10000 iterations --> 394.356 ms
//    Min: 34 µs
//    Max: 141 µs
//   Mean: 39.3686 µs
// Median: 39 µs
// StdDev: 3.9998917535351386 µs
// ========================================
test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    try std.testing.expectEqual(164960, result);
}

test "part 2 small" {
    var reader = Reader.init(
        \\029A
        \\980A
        \\179A
        \\456A
        \\379A
        \\
    );
    const result = part_two(&reader);
    // 2_050_000_000
    try std.testing.expectEqual(154_115_708_116_294, result);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    // 197112 is too low
    // 6858192 is too low
    // 16174438 is too low

    // 233490962379162 not right
    try std.testing.expectEqual(1, result);
}
