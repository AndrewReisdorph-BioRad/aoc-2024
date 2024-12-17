const std = @import("std");

pub const SeekFrom = enum { Start, Current, End };

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

    pub fn get_data(self: *Self) []const u8 {
        return self.data;
    }

    pub fn search_next_int(self: *Self, T: type) ?T {
        if (self.ptr >= self.data.len) {
            return null;
        }
        var value: T = 0;

        // Skip any non-digit characters
        while (self.data[self.ptr] < 48 or self.data[self.ptr] > 57) {
            self.ptr += 1;
            if (self.ptr >= self.data.len) {
                return null;
            }
        }
        const negative = self.ptr > 0 and self.data[self.ptr - 1] == '-';
        while (self.data[self.ptr] >= 48 and self.data[self.ptr] <= 57) {
            value = value * 10 + (self.data[self.ptr] - 48);
            self.ptr += 1;
            if (self.ptr >= self.data.len) {
                break;
            }
        }

        switch (@typeInfo(T)) {
            .Int => |info| {
                if (info.signedness == std.builtin.Signedness.signed) {
                    return if (negative) -value else value;
                }
                return value;
            },
            else => {
                @panic("not called with int");
            },
        }
    }

    pub fn next_int(self: *Self, T: type, ignore_whitespace: bool) ?T {
        var buffer: [32]u8 = undefined;
        var size: u32 = 0;

        const original_ptr = self.ptr;

        while (self.ptr < self.data.len) {
            const char = self.data[self.ptr];
            self.ptr += 1;
            if (std.ascii.isDigit(char)) {
                buffer[size] = char;
                size += 1;
            } else if (size > 0) {
                break;
            } else if (!ignore_whitespace and (char == ' ' or char == '\n')) {
                break;
            }
        }

        if (size == 0) {
            self.ptr = original_ptr;
            return null;
        }

        self.ptr -= 1;

        return std.fmt.parseInt(T, buffer[0..size], 10) catch unreachable;
    }

    pub fn next_u32(self: *Self, ignore_whitespace: bool) ?u32 {
        var buffer: [10:0]u8 = undefined;
        var size: u32 = 0;

        const original_ptr = self.ptr;

        while (self.ptr < self.data.len) {
            const char = self.data[self.ptr];
            self.ptr += 1;
            if (std.ascii.isDigit(char)) {
                buffer[size] = char;
                size += 1;
            } else if (size > 0) {
                break;
            } else if (!ignore_whitespace and (char == ' ' or char == '\n')) {
                break;
            }
        }

        if (size == 0) {
            self.ptr = original_ptr;
            return null;
        }

        self.ptr -= 1;

        return std.fmt.parseInt(u32, buffer[0..size], 10) catch unreachable;
    }

    pub fn next_line(self: *Self) ?[]const u8 {
        if (self.ptr >= self.data.len - 1) {
            return null;
        }
        const line_start = self.ptr;
        while (self.ptr < self.data.len and self.data[self.ptr] != '\n') {
            self.ptr += 1;
        }
        if (line_start == self.ptr) {
            if (self.ptr < self.data.len and self.data[self.ptr] == '\n') {
                self.ptr += 1;
                return &"".*;
            }
            return null;
        }
        self.ptr += 1;
        return self.data[line_start .. self.ptr - 1];
    }

    pub fn peek_previous_char(self: *Self) ?u8 {
        if (self.ptr == 0) {
            return null;
        } else if (self.ptr == 1) {
            return self.data[1];
        }
        return self.data[self.ptr - 2];
    }

    pub fn next_char(self: *Self) ?u8 {
        if (self.ptr >= self.data.len) {
            return null;
        }
        self.ptr += 1;
        return self.data[self.ptr - 1];
    }

    pub fn peak_next_line(self: *Self) ?[]const u8 {
        const original_ptr = self.ptr;
        const line = self.next_line();
        self.ptr = original_ptr;
        return line;
    }

    pub fn seek_to_next_substr(self: *Self, substr: []const u8) ?u32 {
        var completed_substr_idx: u32 = 0;
        while (self.ptr < self.data.len and completed_substr_idx < substr.len) {
            const char = self.data[self.ptr];
            if (char == substr[completed_substr_idx]) {
                completed_substr_idx += 1;
            } else {
                completed_substr_idx = 0;
            }
            self.ptr += 1;
        }
        if (completed_substr_idx == substr.len) {
            self.ptr -= @intCast(substr.len);
            return self.ptr;
        }
        return null;
    }

    pub fn seek(self: *Self, from: SeekFrom, distance: i32) void {
        switch (from) {
            .Current => {
                const new_ptr = @as(i64, self.ptr) + @as(i64, distance);
                self.ptr = @min(@max(0, @as(u32, @intCast(new_ptr))), @as(u32, @intCast(self.data.len - 1)));
            },
            else => {
                @panic("Unhandled");
            },
        }
    }

    pub fn tell(self: *Self) u32 {
        return self.ptr;
    }
};
