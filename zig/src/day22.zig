const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const benchmark = @import("utils/benchmark.zig");

const day = 22;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});

pub fn part_one(reader: *Reader) u64 {
    var sum: u64 = 0;
    while (reader.search_next_int(u64)) |initial| {
        var secret = initial;
        for (0..2000) |_| {
            secret = ((secret * 64) ^ secret) & 0xffffff;
            secret = ((secret / 32) ^ secret) & 0xffffff;
            secret = ((secret * 2048) ^ secret) & 0xffffff;
        }
        sum += secret;
    }

    return sum;
}

const Node = struct { children: [19]?*Node = .{null} ** 19, count: u64 = 0 };

const Graph = struct {
    const Self = @This();
    root: Node = Node{},
    max_bananas: u64 = 0,
    fn insert(self: *Self, address: [4]i8, price: u8, allocator: std.mem.Allocator) void {
        var current = &self.root;
        for (0..address.len) |idx| {
            const child_idx = @as(usize, @intCast(address[idx] + 9));
            if (current.children[child_idx] == null) {
                current.children[child_idx] = allocator.create(Node) catch unreachable;
                current.children[child_idx].?.* = Node{};
            }
            current = current.children[child_idx].?;
        }
        current.count += price;
        // if (address[0] == -2 and address[1] == 1 and address[2] == -1) {
        //     std.debug.print("{any} -- {d} -- {}\n", .{ address, price, current.count });
        // }
        self.max_bananas = @max(self.max_bananas, current.count);
    }
};

const CircularArray = struct {
    const Self = @This();
    data: [4]i8 = undefined,
    len: usize = 0,
    insert: usize = 0,
    read: usize = 0,

    fn push(self: *Self, value: i8) void {
        if (self.insert >= self.data.len) {
            self.insert = 0;
        }
        self.data[self.insert] = value;
        self.insert += 1;
        if (self.len == self.data.len) {
            if (self.read == self.data.len - 1) {
                self.read = 0;
            } else {
                self.read += 1;
            }
        }
        self.len = @min(self.data.len, self.len + 1);
    }

    fn get(self: *Self) [4]i8 {
        var buffer: @TypeOf(self.data) = undefined;
        for (0..self.data.len) |i| {
            const adjusted_idx = (self.read + i) % self.data.len;
            buffer[i] = self.data[adjusted_idx];
        }
        return buffer;
    }

    fn data_as_u32(self: *Self) u32 {
        const buffer = self.get();
        return std.mem.readInt(u32, @ptrCast(&buffer), std.builtin.Endian.little);
    }
};

pub fn part_two(reader: *Reader) u64 {
    const allocator = std.heap.page_allocator;
    var graph: Graph = Graph{};
    var buffer = CircularArray{};
    var prices_for_this_seller = std.AutoHashMap(u32, void).init(allocator);
    var last_price: ?u8 = null;

    while (reader.search_next_int(u64)) |initial| {
        var secret = initial;

        prices_for_this_seller.clearRetainingCapacity();

        for (0..2000) |_| {
            secret = ((secret * 64) ^ secret) & 0xffffff;
            secret = ((secret / 32) ^ secret) & 0xffffff;
            secret = ((secret * 2048) ^ secret) & 0xffffff;

            const price = @as(u8, @intCast(secret % 10));
            // std.debug.print("price: {d} secret: {d} ", .{ price, secret });

            if (last_price) |p| {
                const delta = @as(i8, @intCast(p)) - @as(i8, @intCast(price));
                buffer.push(delta);
                // std.debug.print("delta: {d} deltas: {any}\n", .{ delta, buffer.get() });

                if (buffer.len == 4) {
                    const key = buffer.data_as_u32();
                    if (prices_for_this_seller.get(key) == null) {
                        graph.insert(buffer.get(), price, allocator);
                        prices_for_this_seller.put(key, {}) catch unreachable;
                    }
                }
            } else {
                // std.debug.print("\n", .{});
            }

            last_price = price;
        }
    }

    return graph.max_bananas;
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

test "part 1 sample" {
    var reader = Reader.init(
        \\1
        \\10
        \\100
        \\2024
    );
    const result = part_one(&reader);
    try std.testing.expectEqual(37327623, result);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    try std.testing.expectEqual(20071921341, result);
}

test "part 2 sample" {
    var reader = Reader.init(
        \\1
        \\2
        \\3
        \\2024
    );
    const result = part_two(&reader);
    try std.testing.expectEqual(23, result);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    // 2236 is too low
    try std.testing.expectEqual(1, result);
}
