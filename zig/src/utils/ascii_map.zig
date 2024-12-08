const std = @import("std");

pub fn AsciiMap(T: type) type {
    return struct {
        inner: [256](?T),
        const Self = @This();

        pub fn init() Self {
            var inner: [256](?T) = undefined;
            for (0..256) |k| {
                inner[k] = null;
            }
            return Self{ .inner = inner };
        }

        pub fn set(self: *Self, key: u8, value: T) void {
            self.inner[key] = value;
        }

        pub fn get(self: *Self, key: u8) ?*T {
            if (self.inner[key]) |*value| {
                return value;
            }
            return null;
        }

        pub fn has(self: *Self, key: u8) bool {
            return self.inner[key] != null;
        }
    };
}

test "can create" {
    var map = AsciiMap(std.ArrayList(u32)).init();
    map.set('0', std.ArrayList(u32).init(std.heap.page_allocator));
    map.get('0').?.append(69) catch unreachable;
    try std.testing.expect(map.get(0) == null);
}
