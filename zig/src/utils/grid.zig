pub const Position = struct {
    x: i64,
    y: i64,
    const Self = @This();

    pub fn from_step(self: Self, direction: Direction) Self {
        var new_position = self;
        new_position.move_direction(direction);
        return new_position;
    }

    pub fn move_direction(self: *Self, direction: Direction) void {
        switch (direction) {
            .north => self.north(),
            .south => self.south(),
            .east => self.east(),
            .west => self.west(),
            .northwest => self.north_west(),
            .northeast => self.north_east(),
            .southwest => {
                self.south();
                self.west();
            },
            .southeast => {
                self.south();
                self.east();
            },
        }
    }

    pub fn north(self: *Self) void {
        self.y -= 1;
    }

    pub fn north_east(self: *Self) void {
        self.y -= 1;
        self.x += 1;
    }

    pub fn north_west(self: *Self) void {
        self.y -= 1;
        self.x -= 1;
    }

    pub fn south(self: *Self) void {
        self.y += 1;
    }

    pub fn west(self: *Self) void {
        self.x -= 1;
    }

    pub fn east(self: *Self) void {
        self.x += 1;
    }

    pub fn clone(self: *const Self) Self {
        return self.*;
    }

    pub fn delta(self: *const Self, other: Self) PositionDelta {
        return PositionDelta{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn apply_delta(self: *Self, d: PositionDelta) void {
        self.x += d.x;
        self.y += d.y;
    }
};

pub const PositionDelta = struct {
    x: i64,
    y: i64,
    const Self = @This();

    pub fn invert(self: *Self) *Self {
        self.x *= -1;
        self.y *= -1;
        return self;
    }
};

pub const Direction = enum(u8) {
    north = 1,
    northeast = 2,
    east = 4,
    southeast = 8,
    south = 16,
    southwest = 32,
    west = 64,
    northwest = 128,
    pub fn turn_90_degrees(self: *@This()) void {
        switch (self.*) {
            .north => self.* = Direction.east,
            .east => self.* = Direction.south,
            .south => self.* = Direction.west,
            .west => self.* = Direction.north,
            .northeast => self.* = Direction.southeast,
            .northwest => self.* = Direction.northeast,
            .southeast => self.* = Direction.southwest,
            .southwest => self.* = Direction.northwest,
        }
    }
};

pub const Grid = struct {
    data: []const u8,
    height: u64,
    width: u64,
    const Self = @This();

    pub fn init(data: []const u8) Self {
        // Get width
        var ptr: u64 = 0;
        while (ptr < data.len and data[ptr] != '\n') {
            ptr += 1;
        }
        const width = ptr;
        const height: u64 = @as(u64, @intCast(data.len)) / (width + 1);

        return Self{
            .data = data,
            .height = height,
            .width = width,
        };
    }

    pub fn read(self: *Self, position: Position) ?u8 {
        if (self.get_position_offset(position)) |offset| {
            return self.data[offset];
        }
        return null;
    }

    pub fn get_position_from_offset(self: *Self, offset: u32) ?Position {
        const y = @as(u32, @intCast(@as(u64, offset) / (self.width + 1)));
        const x = offset % (self.width + 1);

        return Position{ .x = @as(i64, @intCast(x)), .y = @as(i64, @intCast(y)) };
    }

    pub fn get_position_offset(self: *Self, position: Position) ?u64 {
        if (position.x < 0 or position.x >= self.width) {
            return null;
        } else if (position.y >= self.height or position.y < 0) {
            return null;
        }
        return (self.width + 1) * @as(u64, @intCast(position.y)) + @as(u64, @intCast(position.x));
    }

    pub fn size(self: *Self) struct { u32, u32 } {
        return .{ self.width, self.height };
    }

    pub fn iter_positions(self: *Self) PositionIterator {
        return PositionIterator.init(self.width, self.height);
    }
};

pub const PositionIterator = struct {
    width: u64,
    height: u64,
    x: i64,
    y: i64,
    done: bool,
    const Self = @This();

    pub fn init(width: u64, height: u64) Self {
        return Self{ .width = width, .height = height, .x = 0, .y = 0, .done = false };
    }

    pub fn next(self: *Self) ?Position {
        if (self.done) {
            return null;
        }

        const next_position = Position{ .x = self.x, .y = self.y };

        if (self.x >= self.width - 1) {
            self.x = 0;
            self.y += 1;
            if (self.y >= self.height) {
                self.done = true;
            }
        } else {
            self.x += 1;
        }

        return next_position;
    }
};
