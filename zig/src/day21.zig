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
    pub fn calc_key(dpads: []DirectionalKeypad, step: u8) u128 {
        var key: u128 = 0;
        for (dpads) |dpad| {
            const next_key_bits: u128 = switch (dpad.current_key()) {
                '^' => 1,
                '<' => 2,
                'v' => 3,
                '>' => 4,
                'A' => 5,
                else => unreachable,
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
    id: usize = 0,
    key_presses: u64 = 0,
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
    pub fn increment_push(self: *Self) void {
        self.key_presses += 1;
        if (self.id == 0) {
            std.debug.print("DPad[{d}] Key Presses: {d}\n", .{ self.id, self.key_presses });
        }
    }
    pub fn push(self: *Self, ship: anytype) void {
        const current = self.current_key();
        std.debug.print("DPad[{d}]:{d} pushing key {c} ---- {d}\n", .{ self.id, self.key_presses, current, ship.dpads[0].key_presses });

        self.increment_push();
        if (self.id < ship.dpads.len - 1) {
            if (current == 'A') {
                ship.dpads[self.id + 1].push(ship);
            } else {
                ship.dpads[self.id + 1].move_direction(current);
                ship.print();
            }
        } else {
            if (current == 'A') {
                ship.numpad.push();
            } else {
                ship.numpad.move_direction(current);
                ship.print();
            }
        }
    }
    pub fn get_key_row(key: u8) u8 {
        return @as(u8, (key != '^' and key != 'A'));
    }
    pub fn get_key_column(key: u8) u8 {
        return switch (key) {
            '<' => 0,
            '^' | 'v' => 1,
            else => 2,
        };
    }
    pub fn calc_paths_to_key(self: *Self, key: u8) KeypadPaths {
        // Four options exists:
        // 0. Key is the current key
        // 1. Key is on same row/column and we only need to move in one direction
        // 2. Move vertically and then horizontally
        // 3. Move horizontally and then vertically
        var paths = KeypadPaths{};
        const current = self.current_key();

        if (key == current) {
            return paths;
        }

        const current_row = Self.get_key_row(current);
        const current_col = Self.get_key_column(current);

        const key_row = Self.get_key_row(key);
        const key_col = Self.get_key_column(key);

        const horizontal_direction = if (current_col > key_col) LEFT else RIGHT;
        const vertical_direction = if (current_row > key_row) UP else DOWN;
        const horizontal_distance = @as(u8, @abs(@as(i8, current_col) - @as(i8, key_col)));
        const vertical_distance = @as(u8, @abs(@as(i8, current_row) - @as(i8, key_row)));

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
            switch (current) {
                '^' => {
                    switch (key) {
                        '<' => {
                            paths.num_paths = 1;
                            paths.paths[0][0] = 'v';
                            paths.paths[0][1] = '<';
                        },
                        '>' => {
                            paths.paths[0][0] = 'v';
                            paths.paths[0][1] = '>';

                            paths.paths[1][0] = '>';
                            paths.paths[1][1] = 'v';
                        },
                        else => unreachable,
                    }
                },
                'A' => {
                    switch (current) {
                        '<' => {
                            paths.paths[0][0] = 'v';
                            paths.paths[0][1] = '<';
                            paths.paths[0][2] = '<';

                            paths.paths[1][0] = '<';
                            paths.paths[1][1] = 'v';
                            paths.paths[1][2] = '<';
                        },
                        'v' => {
                            paths.paths[0][0] = 'v';
                            paths.paths[0][1] = '<';

                            paths.paths[1][0] = '<';
                            paths.paths[1][1] = 'v';
                        },
                        else => unreachable,
                    }
                },
                '<' => {
                    switch (current) {
                        '^' => {
                            paths.num_paths = 1;
                            paths.paths[0][0] = '>';
                            paths.paths[0][1] = '^';
                        },
                        'A' => {
                            paths.paths[0][0] = '>';
                            paths.paths[0][1] = '^';
                            paths.paths[0][2] = '>';

                            paths.paths[1][0] = '>';
                            paths.paths[1][1] = '>';
                            paths.paths[1][2] = '^';
                        },
                        else => unreachable,
                    }
                },
                'v' => {
                    switch (current) {
                        'A' => {
                            paths.paths[0][0] = '>';
                            paths.paths[0][1] = '^';

                            paths.paths[1][0] = '^';
                            paths.paths[1][1] = '>';
                        },
                        else => unreachable,
                    }
                },
                '>' => {
                    switch (current) {
                        '^' => {
                            paths.paths[0][0] = '<';
                            paths.paths[0][1] = '^';

                            paths.paths[1][0] = '^';
                            paths.paths[1][1] = '<';
                        },
                        else => unreachable,
                    }
                },
                else => unreachable,
            }
        }

        return paths;
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
    pub fn current_key(self: *const Self) u8 {
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
        self.increment_push();
        std.debug.print("DPad[{d}] moving {c}\n", .{ self.id, direction });
    }
    pub fn move_to_and_activate_key(self: *Self, key: u8, ship: anytype, lookup: *StepLookup) void {
        std.debug.print("DPad[{d}] moving from {c} to key: {c}  ---- {d}\n", .{ self.id, self.current_key(), key, ship.dpads[0].key_presses });

        const lookup_key = StepLookup.calc_key(ship.dpads[0 .. self.id + 1], key);

        if (CACHE_ENABLED) {
            if (lookup.get(lookup_key)) |key_presses| {
                // Subtract one because we call `.push` later
                ship.dpads[0].key_presses += key_presses - 1;
                std.debug.print("Cached: 0x{X} --> {d} -> {d}", .{ lookup_key, key_presses, ship.dpads[0].key_presses });
                self.current_key_idx = @as(u8, switch (key) {
                    '^' => UP_IDX,
                    '<' => LEFT_IDX,
                    'v' => DOWN_IDX,
                    '>' => RIGHT_IDX,
                    'A' => ACTIVATE_IDX,
                    else => unreachable,
                });
                std.debug.print("DPad[{d}] skipping to key: {c}\n", .{ self.id, key });
                for (0..self.id) |i| {
                    ship.dpads[i].current_key_idx = ACTIVATE_IDX;
                }
                ship.dpads[0].push(ship);
                return;
            }
        }

        const starting_key_presses = ship.dpads[0].key_presses;

        while (self.current_key() != key) {
            const step = self.calc_step_toward_key(key);
            if (self.id == 0) {
                self.move_direction(step);
            } else {
                //std.debug.print("DPad[{d}] needs DPad[{d}] to move to key: {c}\n", .{ self.id, self.id - 1, step });
                ship.dpads[self.id - 1].move_to_and_activate_key(step, ship, lookup);
            }
        }
        //std.debug.print("DPad[{d}] is on target key: {c} \n", .{ self.id, self.current_key() });

        if (self.id == 0) {
            self.push(ship);
        } else {
            ship.dpads[self.id - 1].move_to_and_activate_key('A', ship, lookup);
        }

        const total_key_presses = ship.dpads[0].key_presses - starting_key_presses;
        lookup.put(lookup_key, total_key_presses);
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
    pub fn print(self: *Self) void {
        const current = self.current_key();
        //std.debug.print("   _ _ \n", .{});
        if (current == '^') {
            //std.debug.print(" _|#|A|\n", .{});
        } else if (current == 'A') {
            //std.debug.print(" _|^|#|\n", .{});
        } else {
            //std.debug.print(" _|^|A|\n", .{});
        }

        if (current == '<') {
            //std.debug.print("|#|v|>|\n", .{});
        } else if (current == 'v') {
            //std.debug.print("|<|#|>|\n", .{});
        } else if (current == '>') {
            //std.debug.print("|<|v|#|\n", .{});
        } else {
            //std.debug.print("|<|v|>|\n", .{});
        }
        //std.debug.print(" - - -\n", .{});
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
        std.debug.print("NumPad moved to: {c}\n", .{self.current_key()});
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
                    //std.debug.print("Last direction {c} can be used\n", .{last});
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
    pub fn push(self: *Self) void {
        std.debug.print("=================\nNumpad Entered: {c}\n=================\n", .{self.current_key()});
    }
    pub fn print(self: *Self) void {
        const current = self.current_key();
        //std.debug.print(" _ _ _\n", .{});
        for ("|7|8|9|\n") |c| {
            if (c == current) {
                //std.debug.print("#", .{});
            } else {
                //std.debug.print("{c}", .{c});
            }
        }
        //std.debug.print(" _ _ _\n", .{});
        for ("|4|5|6|\n") |c| {
            if (c == current) {
                //std.debug.print("#", .{});
            } else {
                //std.debug.print("{c}", .{c});
            }
        }
        //std.debug.print(" _ _ _\n", .{});
        for ("|1|2|3|\n") |c| {
            if (c == current) {
                //std.debug.print("#", .{});
            } else {
                //std.debug.print("{c}", .{c});
            }
        }
        //std.debug.print(" _ _ _\n", .{});
        for ("  |0|A|\n") |c| {
            if (c == current) {
                //std.debug.print("#", .{});
            } else {
                //std.debug.print("{c}", .{c});
            }
        }
        //std.debug.print("   _ _\n", .{});
    }
};

fn SpaceShip(num_dpads: comptime_int) type {
    return struct {
        const Self = @This();
        dpads: [num_dpads]DirectionalKeypad = undefined,
        numpad: NumericKeypad = NumericKeypad{},
        pub fn init() Self {
            var new = Self{};
            for (0..num_dpads) |i| {
                new.dpads[i] = DirectionalKeypad{ .id = i };
            }
            return new;
        }
        pub fn print(self: *Self) void {
            for (0..num_dpads) |i| {
                //std.debug.print("DPad: {d}\n", .{i});
                self.dpads[i].print();
            }
            self.numpad.print();
        }
        pub fn follow_numpad_path(self: *Self, path: []const u8, lookup: *StepLookup) void {
            std.debug.print("Following numpad path: {s}\n", .{path});
            std.debug.print("Starting on: {c}\n", .{self.numpad.current_key()});
            for (path) |step| {
                std.debug.print("Stepping: {c}\n", .{step});
                // for (&self.dpads) |*dpad| {
                //     std.debug.print("DPad[{d}] {c}\n", .{ dpad.id, dpad.current_key() });
                // }
                self.dpads[num_dpads - 1].move_to_and_activate_key(step, self, lookup);
            }

            self.dpads[num_dpads - 1].move_to_and_activate_key('A', self, lookup);
        }
    };
}

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
pub fn get_code_button_presses(code: Code, lookup: *StepLookup, num_dpads: comptime_int) u64 {
    std.debug.print("Handling code: {s}\n", .{code});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const Ship = SpaceShip(num_dpads);

    var new_ships = std.ArrayList(Ship).init(allocator);
    defer new_ships.deinit();
    var ships = std.ArrayList(Ship).init(allocator);
    defer ships.deinit();

    ships.append(Ship.init()) catch unreachable;

    var last_key: u8 = 'A';
    for (code) |key| {
        const paths = NumericKeypad.calc_paths_to_key(last_key, key);
        for (ships.items) |*ship| {
            var copy = ship.*;
            //std.debug.print("[1/{}] ", .{paths.num_paths});
            ship.follow_numpad_path(paths.paths[0][0..paths.length], lookup);
            if (paths.num_paths > 1) {
                //std.debug.print("[2/{}] ", .{paths.num_paths});
                copy.follow_numpad_path(paths.paths[1][0..paths.length], lookup);
                new_ships.append(copy) catch unreachable;
            }
        }

        ships.appendSlice(new_ships.items) catch unreachable;
        new_ships.clearRetainingCapacity();

        last_key = key;
    }

    var min_presses: u64 = std.math.maxInt(u64);
    for (ships.items) |ship| {
        min_presses = @min(min_presses, ship.dpads[0].key_presses);
    }

    return min_presses;
}

pub fn part_one(reader: *Reader) u64 {
    var sum: u64 = 0;
    const codes = get_codes(reader);
    var lookup = StepLookup.init(std.heap.page_allocator);
    defer lookup.deinit();
    for (codes) |code| {
        const button_presses = get_code_button_presses(code, &lookup, 2);
        const numeric_value = std.fmt.parseInt(u64, code[0..3], 10) catch unreachable;
        std.debug.print("\n=========================\nPresses: {d} Code: {d}\n=========================\n", .{ button_presses, numeric_value });

        sum += button_presses * numeric_value;
    }

    return sum;
}

pub fn part_two(reader: *Reader) u64 {
    var sum: u64 = 0;
    var lookup = StepLookup.init(std.heap.page_allocator);
    defer lookup.deinit();

    const codes = get_codes(reader);
    for (codes) |code| {
        const button_presses = get_code_button_presses(code, &lookup, 25);
        const numeric_value = std.fmt.parseInt(u64, code[0..3], 10) catch unreachable;
        std.debug.print("\n=========================\nPresses: {d} Code: {d}\n=========================\n", .{ button_presses, numeric_value });

        sum += button_presses * numeric_value;
    }

    return sum;
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
