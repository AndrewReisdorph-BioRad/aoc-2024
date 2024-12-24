const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
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

const Key = struct { code: u8, up: ?usize = null, down: ?usize = null, left: ?usize = null, right: ?usize = null };

const KeypadPaths = struct {
    const Self = @This();
    paths: [2][5]u8 = std.mem.zeroes([2][5]u8),
    num_paths: u8 = 0,
    length: u8 = 0,
};

const DirectionalKeypad = struct {
    const Self = @This();
    const UP_IDX = 0;
    const DOWN_IDX = 1;
    const LEFT_IDX = 2;
    const RIGHT_IDX = 3;
    const ACTIVATE_IDX = 4;
    current_key_idx: usize = ACTIVATE_IDX,
    key_presses: u32 = 0,
    primary: bool = false,
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
    pub fn activate(self: *Self, universe: *Universe) void {
        self.key_presses += 1;
        if (self.primary) {
            if (self.keys[self.current_key_idx].code == 'A') {
                universe.secondary_dpad.activate(universe);
            } else {
                universe.secondary_dpad.move_direction(self.keys[self.current_key_idx].code);
            }
        } else {
            if (self.keys[self.current_key_idx].code == 'A') {
                universe.numpad.activate();
            } else {
                universe.numpad.move_direction(self.keys[self.current_key_idx].code);
            }
        }
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
        self.key_presses += 1;
    }
    pub fn move_to_key(self: *Self, key: u8) void {
        while (self.current_key() != key) {
            const keypad_b_step = self.calc_step_toward_key(key);
            self.move_direction(keypad_b_step);
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
        // std.debug.print("NumPad is on: {c}\n", .{self.current_key()});
    }
    pub fn current_key(self: *Self) u8 {
        return self.keys[self.current_key_idx].code;
    }
    pub fn key_dist(key_a: u8, key_b: u8) u8 {
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
            const direction: u8 = if (key_row > current_row) DOWN else UP;
            paths.num_paths = 1;
            paths.length = @abs(@as(i8, @intCast(key_row)) - @as(i8, @intCast(current_row)));
            for (0..paths.length) |i| {
                paths.paths[0][i] = direction;
            }
            return paths;
        }

        if (key_row == current_row) {
            const direction: u8 = if (key_column > current_column) RIGHT else LEFT;
            paths.num_paths = 1;
            paths.length = @abs(@as(i8, @intCast(key_column)) - @as(i8, @intCast(current_column)));
            for (0..paths.length) |i| {
                paths.paths[0][i] = direction;
            }
            return paths;
        }

        const vertical_direction: u8 = if (key_row > current_row) DOWN else UP;
        const horizontal_direction: u8 = if (key_column > current_column) RIGHT else LEFT;
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
            paths.paths[1][0] = '<';
            paths.paths[1][1] = '^';
            paths.paths[1][2] = '<';
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
            paths.paths[1][vertical_distance - 1] = '>';
            paths.paths[1][vertical_distance] = 'v';
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
    pub fn reset(self: *Self) void {
        self.current_key_idx = ACTIVATE_IDX;
    }
    pub fn activate(self: *Self) void {
        _ = self;
        // std.debug.print("=================\nNumpad Entered: {c}\n=================\n", .{self.current_key()});
    }
};

const Universe = struct {
    const Self = @This();
    primary_dpad: DirectionalKeypad = DirectionalKeypad{ .primary = true },
    secondary_dpad: DirectionalKeypad = DirectionalKeypad{},
    numpad: NumericKeypad = NumericKeypad{},
    pub fn follow_numpad_path(self: *Self, path: []const u8) void {
        // std.debug.print("Following numpad path: {s}\n", .{path});
        // std.debug.print("Starting on: {c}\n", .{self.numpad.current_key()});

        // Position the numeric keypad cursor over next_digit
        for (path) |step| {
            // Move Secondary D-Pad cursor to the button of the direction we want to move the cursor on the num pad
            while (self.secondary_dpad.current_key() != step) {
                const keypad_a_step = self.secondary_dpad.calc_step_toward_key(step);
                self.primary_dpad.move_to_key(keypad_a_step);
                self.primary_dpad.activate(self);
            }
            // Move Primary cursor to 'A' key and push it
            self.primary_dpad.move_to_key(ACTIVATE);
            self.primary_dpad.activate(self);
        }

        // Move Secondary cursor to 'A'
        while (self.secondary_dpad.current_key() != 'A') {
            const keypad_a_step = self.secondary_dpad.calc_step_toward_key('A');
            self.primary_dpad.move_to_key(keypad_a_step);
            self.primary_dpad.activate(self);
        }

        // Move Primary cursor to 'A' key and push it to activate Secondary to activate the numpad push
        self.primary_dpad.move_to_key(ACTIVATE);
        self.primary_dpad.activate(self);
    }
};

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

// Assumptions:
// 1. It is always most efficient to move in straight lines i.e. no stair steps
pub fn get_code_button_presses(code: Code) u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var new_universes = std.ArrayList(Universe).init(allocator);
    defer new_universes.deinit();
    var universes = std.ArrayList(Universe).init(allocator);
    defer universes.deinit();

    universes.append(Universe{}) catch unreachable;

    var last_key: u8 = 'A';
    for (code) |key| {
        const paths = NumericKeypad.calc_paths_to_key(last_key, key);
        for (universes.items) |*universe| {
            var copy = universe.*;
            universe.follow_numpad_path(paths.paths[0][0..paths.length]);
            if (paths.num_paths > 1) {
                copy.follow_numpad_path(paths.paths[1][0..paths.length]);
                new_universes.append(copy) catch unreachable;
            }
        }

        universes.appendSlice(new_universes.items) catch unreachable;
        new_universes.clearRetainingCapacity();

        last_key = key;
    }

    var min_presses: u64 = std.math.maxInt(u64);
    for (universes.items) |universe| {
        min_presses = @min(min_presses, universe.primary_dpad.key_presses);
    }

    return min_presses;
}

pub fn part_one(reader: *Reader) u64 {
    var sum: u64 = 0;
    const codes = get_codes(reader);
    for (codes) |code| {
        const button_presses = get_code_button_presses(code);
        const numeric_value = std.fmt.parseInt(u64, code[0..3], 10) catch unreachable;
        sum += button_presses * numeric_value;
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
    try std.testing.expectEqual(164960, result);
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
