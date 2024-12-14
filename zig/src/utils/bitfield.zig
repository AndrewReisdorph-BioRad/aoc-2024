const std = @import("std");

pub fn Bitfield(length: comptime_int) type {
    return struct {
        const byte_length = @divFloor(length, 8) + 1;
        data: [byte_length]u8 = undefined,
        count: u32,
        const Self = @This();

        pub fn init() Self {
            return Self{ .count = 0, .data = std.mem.zeroes([byte_length]u8) };
        }

        pub fn set(self: *Self, position: u64) void {
            const is_set = self.get(position);
            if (is_set) {
                return;
            }
            const byte_offset = @divFloor(position, 8);
            const bit_offset = @mod(position, 8);

            self.data[byte_offset] |= @as(u8, 1) << @intCast(bit_offset);
            self.count += 1;
        }

        pub fn setAndGetByte(self: *Self, position: u64) u8 {
            const byte_offset = @divFloor(position, 8);
            const bit_offset = @mod(position, 8);

            self.data[byte_offset] |= @as(u8, 1) << @intCast(bit_offset);
            self.count += 1;
            return self.data[byte_offset];
        }

        pub fn get(self: *Self, position: u64) bool {
            const byte_offset = @divFloor(position, 8);
            const bit_offset = @mod(position, 8);
            return (self.data[byte_offset] & @as(u8, 1) << @intCast(bit_offset)) > 0;
        }

        pub fn clear(self: *Self) void {
            self.count = 0;
            @memset(&self.data, 0);
        }
    };
}
