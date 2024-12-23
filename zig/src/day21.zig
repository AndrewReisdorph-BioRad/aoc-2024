const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const benchmark = @import("utils/benchmark.zig");

const day = 21;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});

const UP = '^';
const DOWN = 'v';
const LEFT = '<';
const RIGHT = '>';
const ACTIVATE = 'A';

const Key = struct { code: u8, up: ?usize = null, down: ?usize = null, left: ?usize = null, right: ?usize = null };

const DirectionalKeypad = struct {
    const Self = @This();
    const UP_IDX = 0;
    const DOWN_IDX = 1;
    const LEFT_IDX = 2;
    const RIGHT_IDX = 3;
    const ACTIVATE_IDX = 4;
    current_key_idx: usize = ACTIVATE_IDX,
    keys: [5]Key = .{ Key{ .code = UP, .right = ACTIVATE_IDX, .down = DOWN_IDX }, Key{ .code = DOWN, .left = LEFT_IDX, .right = RIGHT_IDX, .up = UP_IDX }, Key{ .code = LEFT, .right = DOWN_IDX }, Key{ .code = RIGHT, .left = DOWN_IDX, .up = ACTIVATE_IDX }, Key{ .code = ACTIVATE, .left = UP_IDX, .down = RIGHT_IDX } },
    pub fn right(self: *Self) void {
        self.current_key_idx = self.keys[self.current_key_idx].right.?;
    }
    pub fn left(self: *Self) void {
        self.current_key_idx = self.keys[self.current_key_idx].left.?;
    }
    pub fn up(self: *Self) void {
        self.current_key_idx = self.keys[self.current_key_idx].up.?;
    }
    pub fn down(self: *Self) void {
        self.current_key_idx = self.keys[self.current_key_idx].down.?;
    }
    pub fn calc_step_toward_key(self: *Self, key: u8) u8 {
        if (key == self.current_key()) {
            return ACTIVATE;
        }
        if (self.current_key_idx == ACTIVATE_IDX) {
            if (key == RIGHT or key == LEFT) {
                return DOWN;
            }
            return LEFT;
        }
        if (self.current_key_idx == UP_IDX) {
            if (key == ACTIVATE) {
                return RIGHT;
            }
            return DOWN;
        }
        if (self.current_key_idx == LEFT_IDX) {
            return RIGHT;
        }
        if (self.current_key_idx == DOWN_IDX) {
            if (key == ACTIVATE) {
                return RIGHT;
            }
            return key;
        }
        if (self.current_key_idx == RIGHT_IDX) {
            if (key == ACTIVATE) {
                return UP;
            }
            return LEFT;
        }
        unreachable;
    }
    pub fn current_key(self: *Self) u8 {
        return self.keys[self.current_key_idx].code;
    }
    pub fn move_direction(self: *Self, direction: u8) void {
        switch (direction) {
            '^' => self.up(),
            '>' => self.right(),
            'v' => self.down(),
            '<' => self.left(),
            else => unreachable,
        }
    }
    pub fn num_key_presses_to_move_to_activate_key(self: *Self) u8 {
        return switch (self.current_key()) {
            'A' => 0,
            '^' => 1,
            '<' => 3,
            'v' => 2,
            '>' => 1,
            else => unreachable,
        };
    }
    pub fn reset(self: *Self) void {
        self.current_key_idx = ACTIVATE_IDX;
    }
};

const NumericKeypad = struct {
    const Self = @This();
    const ACTIVATE_IDX = 10;
    current_key_idx: usize = ACTIVATE_IDX,
    last_direction: ?u8 = UP,
    keys: [11]Key = .{
        Key{ .code = '0', .up = 2, .right = ACTIVATE_IDX },
        Key{ .code = '1', .up = 4, .right = 2 },
        Key{ .code = '2', .up = 5, .right = 3, .down = 0, .left = 1 },
        Key{ .code = '3', .up = 6, .down = ACTIVATE_IDX, .left = 2 },
        Key{ .code = '4', .up = 7, .right = 5, .down = 1 },
        Key{ .code = '5', .up = 8, .right = 6, .down = 2, .left = 4 },
        Key{ .code = '6', .up = 9, .down = 3, .left = 5 },
        Key{ .code = '7', .right = 8, .down = 4 },
        Key{ .code = '8', .left = 7, .right = 9, .down = 5 },
        Key{ .code = '9', .left = 8, .down = 6 },
        Key{ .code = ACTIVATE, .up = 3, .left = 0 },
    },
    pub fn right(self: *Self) void {
        self.current_key_idx = self.keys[self.current_key_idx].right.?;
    }
    pub fn left(self: *Self) void {
        self.current_key_idx = self.keys[self.current_key_idx].left.?;
    }
    pub fn up(self: *Self) void {
        self.current_key_idx = self.keys[self.current_key_idx].up.?;
    }
    pub fn down(self: *Self) void {
        self.current_key_idx = self.keys[self.current_key_idx].down.?;
    }
    pub fn move_direction(self: *Self, direction: u8) void {
        switch (direction) {
            '^' => self.up(),
            '>' => self.right(),
            'v' => self.down(),
            '<' => self.left(),
            else => unreachable,
        }
        self.last_direction = direction;
    }
    pub fn current_key(self: *Self) u8 {
        return self.keys[self.current_key_idx].code;
    }
    pub fn key_dist(key_a: u8, key_b: u8) u8 {
        std.debug.print("key dist {d}  {d}\n", .{ key_a, key_b });
        // determine column for requested key
        var key_a_column: u8 = 0; // left column
        if (key_a == 'A') {
            key_a_column = 2;
        } else if (key_a == '0') {
            key_a_column = 1;
        } else if ((key_a - 47) % 3 == 0) {
            key_a_column = 1; // middle column
        } else if ((key_a - 48) % 3 == 0) {
            key_a_column = 2; // right column
        }

        var key_a_row: u8 = 3;
        if (key_a == 'A') {
            key_a_row = 3;
        } else if ((key_a - 48) >= 7) {
            key_a_row = 0;
        } else if ((key_a - 48) >= 4) {
            key_a_row = 1;
        } else if ((key_a - 48) >= 1) {
            key_a_row = 2;
        }

        var key_b_column: u8 = 0;
        if (key_b == 'A') {
            key_b_column = 2;
        } else if (key_b == '0') {
            key_b_column = 1;
        } else if ((key_b - 47) % 3 == 0) {
            key_b_column = 1;
        } else if ((key_b - 48) % 3 == 0) {
            key_b_column = 2;
        }

        var key_b_row: u8 = 3;
        if (key_b == 'A') {
            key_b_row = 3;
        } else if ((key_b - 48) >= 7) {
            key_b_row = 0;
        } else if ((key_b - 48) >= 4) {
            key_b_row = 1;
        } else if ((key_b - 48) >= 1) {
            key_b_row = 2;
        }

        return @as(u8, @intCast(@abs(@as(i16, key_a_column) - @as(i16, key_b_column)) + @abs(@as(i16, key_a_row) - @as(i16, key_b_row))));
    }
    pub fn calc_step_toward_key(self: *Self, key: u8) u8 {
        // Check if current key is requested key
        const current = self.current_key();
        const key_as_digit = key - 48;
        if (key == current) {
            return ACTIVATE;
        }

        const current_distance_to_key = Self.key_dist(key, self.current_key());

        if (self.last_direction) |last| {
            // If we can continue in the same direction that we've been traveling, do that
            const maybe_same_direction_key = switch (last) {
                UP => self.keys[self.current_key_idx].up,
                DOWN => self.keys[self.current_key_idx].down,
                LEFT => self.keys[self.current_key_idx].left,
                RIGHT => self.keys[self.current_key_idx].right,
                else => unreachable,
            };
            if (maybe_same_direction_key) |same_direction_key| {
                const same_direction_key_dist = Self.key_dist(key, self.keys[same_direction_key].code);
                if (same_direction_key_dist < current_distance_to_key) {
                    std.debug.print("Last direction {c} can be used\n", .{last});
                    return last;
                }
            }
        }

        // determine column for requested key
        var key_column: u8 = 0; // left column
        if (key == 'A') {
            key_column = 2;
        } else if (key_as_digit == 0) {
            key_column = 1;
        } else if ((key_as_digit + 1) % 3 == 0) {
            key_column = 1; // middle column
        } else if (key_as_digit % 3 == 0) {
            key_column = 2; // right column
        }

        var current_column: u8 = 0;
        if (current == 'A') {
            current_column = 2;
        } else if (current == '0') {
            current_column = 1;
        } else if ((self.current_key_idx + 1) % 3 == 0) {
            current_column = 1;
        } else if (self.current_key_idx % 3 == 0) {
            current_column = 2;
        }

        // Special case for A
        if (current == 'A') {
            if (key_column == current_column) {
                return UP;
            }
            if (key_column == 0) {
                return UP;
            }
            if (key_column == 1) {
                return LEFT;
            }
        }

        if (key_column == current_column) {
            if (key == 'A' or key_as_digit < self.current_key_idx) {
                return DOWN;
            }
        }

        // Check if key is to the left
        if (key_column < current_column) {
            return LEFT;
        } else if (key_column > current_column) {
            return RIGHT;
        }

        return UP;
    }

    pub fn calc_step_toward_key2(self: *Self, key: u8) u8 {
        // Check if current key is requested key
        const current = self.current_key();
        const key_as_digit = key - 48;
        if (key == current) {
            return ACTIVATE;
        }

        // Special case for zero
        if (self.current_key_idx == 0) {
            if (key == ACTIVATE) {
                return RIGHT;
            }
            // right column
            if (key_as_digit % 3 == 0) {
                return RIGHT;
            }
            // left or middle column
            return UP;
        }

        // determine column for requested key
        var key_column: u8 = 0; // left column
        if (key == 'A') {
            key_column = 2;
        } else if (key_as_digit == 0) {
            key_column = 1;
        } else if ((key_as_digit + 1) % 3 == 0) {
            key_column = 1; // middle column
        } else if (key_as_digit % 3 == 0) {
            key_column = 2; // right column
        }

        // Special case for activate
        if (current == 'A') {
            // left or middle column
            if (key_as_digit == 0 or key_column == 1) {
                return LEFT;
            }
            // right column
            return UP;
        }

        var current_column: u8 = 0;
        if ((self.current_key_idx + 1) % 3 == 0) {
            current_column = 1;
        } else if (self.current_key_idx % 3 == 0) {
            current_column = 2;
        }

        std.debug.print("Key({c}) col: {d} Current col: {}\n", .{ key, key_column, current_column });

        // Check if key is to the left
        if (key_column < current_column) {
            return LEFT;
        } else if (key_column > current_column) {
            return RIGHT;
        }

        // key is in same column
        if (key == 'A' or key_as_digit < self.current_key_idx) {
            return DOWN;
        }
        return UP;
    }
    pub fn reset(self: *Self) void {
        self.current_key_idx = ACTIVATE_IDX;
    }
};

pub fn part_one(reader: *Reader) u64 {
    var num_pad = NumericKeypad{};
    var d_pad_a = DirectionalKeypad{};
    var d_pad_b = DirectionalKeypad{};

    // 029A: <vA<AA>>^AvAA<^A>A  <v<A>>^AvA^A <vA>^A<v<A>^A>AAvA^A<v<A>A>^AAAvA<^A>A
    //         v <<   A >>  ^ A     <   A >
    //                <       A         ^
    //                        0

    // 379A: <v<A>>^AvA^A <vA<AA>>^AAvA<^A>AAvA^A<vA>^AA<A>A<v<A>A>^AAAvA<^A>A
    //                      v <<   AA >  ^ AA > A  v  AA
    //                             <<      ^^   7
    //       v<<A>>^AvA^A v<<A>>^AA<vA<A>>^AAvAA<^A>A
    //                       <   AA  v <   AA >>  ^ A
    //                           ^^        <<       A
    //                  3                           7
    var sum: u64 = 0;
    var key_presses_for_this_code: u64 = 0;
    var code_numeric_value: u64 = 0;
    while (reader.next_char()) |next_char| {
        if (next_char == '\n') {
            std.debug.print("Key presses: {d} Value: {}\n", .{ key_presses_for_this_code, code_numeric_value });
            std.debug.print("===============================================================\n", .{});
            sum += key_presses_for_this_code * code_numeric_value;
            key_presses_for_this_code = 0;
            code_numeric_value = 0;
        } else {
            if (next_char != 'A') {
                code_numeric_value = code_numeric_value * 10 + (next_char - 48);
            }

            std.debug.print("Next Key: {c}\n", .{next_char});
            // Position the numeric keypad cursor over next_digit
            while (num_pad.current_key() != next_char) {
                const numeric_step = num_pad.calc_step_toward_key(next_char);
                // Move D-Pad A cursor to the button of the direction we want to move the cursor on the num pad
                std.debug.print("Num Pad is on {c} and needs to move {c} towards {c}.\n", .{ num_pad.current_key(), numeric_step, next_char });
                while (d_pad_a.current_key() != numeric_step) {
                    const keypad_a_step = d_pad_a.calc_step_toward_key(numeric_step);
                    // std.debug.print("D-Pad A is on '{c}' and needs to move {c} towards {c}.\n", .{ d_pad_a.current_key(), keypad_a_step, numeric_step });
                    while (d_pad_b.current_key() != keypad_a_step) {
                        const keypad_b_step = d_pad_b.calc_step_toward_key(keypad_a_step);
                        // std.debug.print("D-Pad B is on '{c}' and needs to move {c} towards {c}.\n", .{ d_pad_b.current_key(), keypad_b_step, keypad_a_step });
                        d_pad_b.move_direction(keypad_b_step);
                        std.debug.print("                                    Hitting key: '{c}'\n", .{keypad_b_step});
                        key_presses_for_this_code += 1;
                    }
                    // std.debug.print("D-Pad B is on '{c}' Activating.\n", .{d_pad_b.current_key()});
                    std.debug.print("                                    Hitting key: 'A'\n", .{});
                    key_presses_for_this_code += 1;

                    d_pad_a.move_direction(keypad_a_step);
                }
                // Move D-Pad B cursor to 'A' key and push it
                while (d_pad_b.current_key() != 'A') {
                    const keypad_b_step = d_pad_b.calc_step_toward_key('A');
                    // std.debug.print("D-Pad B is on '{c}' and needs to move {c} towards A.\n", .{ d_pad_b.current_key(), keypad_b_step });
                    d_pad_b.move_direction(keypad_b_step);
                    std.debug.print("                                    Hitting key: '{c}'\n", .{keypad_b_step});
                    key_presses_for_this_code += 1;
                }
                std.debug.print("                                    Hitting key: 'A'\n", .{});
                key_presses_for_this_code += 1;

                num_pad.move_direction(numeric_step);
            }
            std.debug.print("Num Pad is on {c}\n", .{num_pad.current_key()});

            // Move D-Pad A cursor to 'A'
            while (d_pad_a.current_key() != 'A') {
                const keypad_a_step = d_pad_a.calc_step_toward_key('A');
                // std.debug.print("D-Pad A is on '{c}' and needs to move {c} towards A.\n", .{ d_pad_a.current_key(), keypad_a_step });
                while (d_pad_b.current_key() != keypad_a_step) {
                    const keypad_b_step = d_pad_b.calc_step_toward_key(keypad_a_step);
                    // std.debug.print("D-Pad B is on '{c}' and needs to move {c} towards {c}.\n", .{ d_pad_b.current_key(), keypad_b_step, keypad_a_step });
                    d_pad_b.move_direction(keypad_b_step);
                    std.debug.print("                                    Hitting key: '{c}'\n", .{keypad_b_step});
                    key_presses_for_this_code += 1;
                }
                // std.debug.print("D-Pad B is on '{c}' Activating.\n", .{d_pad_b.current_key()});
                std.debug.print("                                    Hitting key: 'A'\n", .{});
                key_presses_for_this_code += 1;

                d_pad_a.move_direction(keypad_a_step);
            }
            // std.debug.print("D-Pad A is on {c}\n", .{d_pad_a.current_key()});

            // Move D-Pad B cursor to 'A' key and push it to activate D-Pad A to activate the numpad push
            while (d_pad_b.current_key() != 'A') {
                const keypad_b_step = d_pad_b.calc_step_toward_key('A');
                // std.debug.print("D-Pad B is on '{c}' and needs to move {c} towards A.\n", .{ d_pad_b.current_key(), keypad_b_step });
                d_pad_b.move_direction(keypad_b_step);
                std.debug.print("                                    Hitting key: '{c}'\n", .{keypad_b_step});
                key_presses_for_this_code += 1;
            }
            std.debug.print("                                    Hitting key: A\n", .{});
            key_presses_for_this_code += 1;
            // num_pad.last_direction = null;
            std.debug.print("=================\nNumpad Entered: {c}\n=================\n", .{next_char});
        }
    }

    return sum;
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

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    // 169164 is too high
    try std.testing.expectEqual(1, result);
}

test "part 2 small" {
    var reader = Reader.init(
        \\sample data
        \\goes here
    );
    const result = part_two(&reader);
    try std.testing.expectEqual(1, result);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    try std.testing.expectEqual(1, result);
}
