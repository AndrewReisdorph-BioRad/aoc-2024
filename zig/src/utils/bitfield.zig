const std = @import("std");

pub fn Bitfield(length: comptime_int) type {
    return struct {
        data: [@divFloor(length, @sizeOf(u8)) + 1]u8 = undefined,
        count: u32,
        const Self = @This();

        pub fn init() Self {
            return Self{ .count = 0, .data = std.mem.zeroes([@divFloor(length, @sizeOf(u8)) + 1]u8) };
        }

        pub fn set(self: *Self, position: u64) void {
            const is_set = self.get(position);
            if (is_set) {
                return;
            }
            const byte_offset = @divFloor(position, @sizeOf(u8));
            const bit_offset = @mod(position, @sizeOf(u8));

            self.data[byte_offset] |= @as(u8, 1) << @intCast(bit_offset);
            self.count += 1;
        }

        pub fn get(self: *Self, position: u64) bool {
            const byte_offset = @divFloor(position, @sizeOf(u8));
            const bit_offset = @mod(position, @sizeOf(u8));
            return (self.data[byte_offset] & @as(u8, 1) << @intCast(bit_offset)) > 0;
        }
    };
}
