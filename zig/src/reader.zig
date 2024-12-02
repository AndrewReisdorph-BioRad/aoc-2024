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

    pub fn next_line(self: *Self) ?[]const u8 {
        const line_start = self.ptr;
        while (self.ptr < self.data.len and self.data[self.ptr] != '\n') {
            self.ptr += 1;
        }
        if (line_start == self.ptr) {
            return null;
        }
        self.ptr += 1;
        return self.data[line_start .. self.ptr - 1];
    }

    pub fn peak_next_line(self: *Self) ?[]const u8 {
        const original_ptr = self.ptr;
        const line = self.next_line();
        self.ptr = original_ptr;
        return line;
    }
};
