pub fn Stack(T: type, length: comptime_int) type {
    return struct {
        data: [length]T,
        size: usize,
        const Self = @This();

        pub fn init() Self {
            return Self{ .data = undefined, .size = 0 };
        }

        pub fn push(self: *Self, value: T) !void {
            if (self.size >= self.data.len - 1) {
                return error.stackOverflow;
            }
            self.data[self.size] = value;
            self.size += 1;
            return;
        }

        pub fn clear(self: *Self) void {
            self.size = 0;
        }

        pub fn pop(self: *Self) ?T {
            if (self.size == 0) {
                return null;
            }
            self.size -= 1;
            return self.data[self.size];
        }

        pub fn peek(self: *Self) ?T {
            if (self.size == 0) {
                return null;
            }
            return self.data[self.size - 1];
        }
    };
}
