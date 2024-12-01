const std = @import("std");

pub const Reader = struct {
    data: []const u8,
    ptr: u32,
    const Self = @This();

    pub fn from_comptime_path(comptime path: []const u8) Self {
        const data = @embedFile(path);
        return Self.init(data);
    }

    pub fn init(data: []const u8) Self {
        return Self{ .data = data, .ptr = 0 };
    }

    pub fn next_u32(self: *Self) ?u32 {
        var buffer: [10:0]u8 = undefined;
        var size: u32 = 0;

        while (self.ptr < self.data.len) {
            const next_char = self.data[self.ptr];
            self.ptr += 1;
            if (next_char == ' ' or next_char == '\n') {
                if (size > 0) {
                    break;
                }
            } else {
                buffer[size] = next_char;
                size += 1;
            }
        }

        if (size == 0) {
            return null;
        }

        return std.fmt.parseInt(u32, buffer[0..size], 10) catch unreachable;
    }
};
