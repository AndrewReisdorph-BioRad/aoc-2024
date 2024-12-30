const std = @import("std");

pub fn Bitfield(length: comptime_int) type {
    return struct {
        const byte_length = @divFloor(length, std.mem.byte_size_in_bits) + 1;
        data: [byte_length]u8 = std.mem.zeroes([byte_length]u8),
        count: u32 = 0,
        const Self = @This();

        // TODO: Deprecate this
        pub fn init() Self {
            return Self{ .count = 0, .data = std.mem.zeroes([byte_length]u8) };
        }

        pub fn set(self: *Self, position: u64) void {
            const is_set = self.get(position);
            if (is_set) {
                return;
            }
            const byte_offset = @divFloor(position, std.mem.byte_size_in_bits);
            const bit_offset = @mod(position, std.mem.byte_size_in_bits);

            self.data[byte_offset] |= @as(u8, 1) << @intCast(bit_offset);
            self.count += 1;
        }

        pub fn setAndGetByte(self: *Self, position: u64) u8 {
            const byte_offset = @divFloor(position, std.mem.byte_size_in_bits);
            const bit_offset = @mod(position, std.mem.byte_size_in_bits);

            self.data[byte_offset] |= @as(u8, 1) << @intCast(bit_offset);
            self.count += 1;
            return self.data[byte_offset];
        }

        pub fn get(self: *const Self, position: u64) bool {
            const byte_offset = @divFloor(position, std.mem.byte_size_in_bits);
            const bit_offset = @mod(position, std.mem.byte_size_in_bits);
            return (self.data[byte_offset] & @as(u8, 1) << @intCast(bit_offset)) > 0;
        }

        pub fn clear(self: *Self) void {
            self.count = 0;
            @memset(&self.data, 0);
        }

        pub fn clone(self: *Self) Self {
            return self.*;
        }

        fn count_bits(value: u8) u8 {
            var bit_count: u8 = 0;
            for (0..8) |bit| {
                if ((value & (@as(u8, 1) << @intCast(bit))) > 0) {
                    bit_count += 1;
                }
            }
            return bit_count;
        }

        pub fn or_items(self: *Self, other: *Self) void {
            for (0..byte_length) |idx| {
                if (other.data[idx] == 0) {
                    continue;
                }
                // Count the bits that have changed
                self.count += Self.count_bits(~self.data[idx] & other.data[idx]);
                self.data[idx] |= other.data[idx];
            }
        }

        pub fn from_and(a: *Self, b: *Self) Self {
            var new = @TypeOf(a.*){};

            for (0..byte_length) |idx| {
                // Count the bits that have changed
                new.data[idx] = a.data[idx] & b.data[idx];
                if (new.data[idx] > 0) {
                    new.count += Self.count_bits(new.data[idx]);
                }
            }

            return new;
        }

        pub fn iter(self: *Self) BitfieldIter(length) {
            return BitfieldIter(length).init(self);
        }
    };
}

fn BitfieldIter(length: comptime_int) type {
    return struct {
        const Self = @This();
        bitfield: *Bitfield(length),
        bit_iter: usize = 0,
        pub fn init(bitfield: *Bitfield(length)) Self {
            return Self{ .bitfield = bitfield };
        }
        pub fn next(self: *Self) ?usize {
            const max_idx = length - 1;
            while (self.bit_iter <= max_idx) {
                const byte_idx = self.bit_iter / std.mem.byte_size_in_bits;
                if (self.bitfield.data[byte_idx] == 0) {
                    self.bit_iter += std.mem.byte_size_in_bits;
                } else {
                    while (self.bit_iter <= max_idx) {
                        if (self.bitfield.get(self.bit_iter)) {
                            self.bit_iter += 1;
                            return self.bit_iter - 1;
                        } else {
                            self.bit_iter += 1;
                        }
                    }
                }
            }
            return null;
        }
    };
}

test "BitfieldIter" {
    var bitfield = Bitfield(400){};
    bitfield.set(345);
    bitfield.set(399);

    bitfield.set(234);
    bitfield.set(0);
    bitfield.set(1);
    bitfield.set(2);
    bitfield.set(3);
    bitfield.set(4);
    bitfield.set(5);
    bitfield.set(6);
    bitfield.set(7);
    bitfield.set(8);

    bitfield.set(12);
    var iter = bitfield.iter();
    while (iter.next()) |idx| {
        std.debug.print("{d}\n", .{idx});
    }
}
