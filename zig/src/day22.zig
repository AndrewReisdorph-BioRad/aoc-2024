const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const benchmark = @import("utils/benchmark.zig");
const BitField = @import("utils/bitfield.zig").Bitfield;

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

const Graph = struct {
    const Self = @This();
    nodes: [19][19][19][19]u16 = std.mem.zeroes([19][19][19][19]u16),
    max: u16 = 0,
    fn insert(self: *Self, address: [4]i8, price: u8) void {
        const node = &self.nodes[@as(usize, @intCast(address[0] + 9))][@as(usize, @intCast(address[1] + 9))][@as(usize, @intCast(address[2] + 9))][@as(usize, @intCast(address[3] + 9))];
        node.* += price;
        self.max = @max(self.max, node.*);
    }
};

const DeltaSet = struct {
    const Self = @This();
    // For some reason using 19][19][19][19]u1 here causes the compiler to hang, but tests run just fine
    seen: [19][19][19][19]u8 = std.mem.zeroes([19][19][19][19]u8),
    fn set(self: *Self, address: [4]i8) void {
        self.seen[@as(usize, @intCast(address[0] + 9))][@as(usize, @intCast(address[1] + 9))][@as(usize, @intCast(address[2] + 9))][@as(usize, @intCast(address[3] + 9))] = 1;
    }
    fn get(self: *Self, address: [4]i8) bool {
        return self.seen[@as(usize, @intCast(address[0] + 9))][@as(usize, @intCast(address[1] + 9))][@as(usize, @intCast(address[2] + 9))][@as(usize, @intCast(address[3] + 9))] == 1;
    }
    fn reset(self: *Self) void {
        self.seen = std.mem.zeroes(@TypeOf(self.seen));
    }
};

const CircularArray = struct {
    const Self = @This();
    data: [4]i8 = undefined,
    len: usize = 0,
    write: usize = 0,
    read: usize = 0,

    fn push(self: *Self, value: i8) void {
        if (self.write >= self.data.len) {
            self.write = 0;
        }
        self.data[self.write] = value;
        self.write += 1;
        if (self.len == self.data.len) {
            if (self.read == self.data.len - 1) {
                self.read = 0;
            } else {
                self.read += 1;
            }
        }
        self.len = @min(self.data.len, self.len + 1);
    }

    fn get(self: *Self) @TypeOf(self.data) {
        var buffer: @TypeOf(self.data) = undefined;
        for (0..self.data.len) |i| {
            const adjusted_idx = (self.read + i) % self.data.len;
            buffer[i] = self.data[adjusted_idx];
        }
        return buffer;
    }

    fn full(self: *Self) bool {
        return self.len == self.data.len;
    }

    fn reset(self: *Self) void {
        @memset(&self.data, 0);
        self.len = 0;
        self.read = 0;
        self.write = 0;
    }

    fn data_as_u32(self: *Self) u32 {
        const buffer = self.get();
        return std.mem.readInt(u32, @ptrCast(&buffer), std.builtin.Endian.little);
    }
};

const Secret = struct {
    const Self = @This();
    inner: u64 = 0,
    pub fn cycle(self: *Self) void {
        self.inner = ((self.inner * 64) ^ self.inner) & 0xffffff;
        self.inner = ((self.inner / 32) ^ self.inner) & 0xffffff;
        self.inner = ((self.inner * 2048) ^ self.inner) & 0xffffff;
    }
    pub fn price(self: *Self) u8 {
        return @as(u8, @intCast(self.inner % 10));
    }
};

pub fn part_two(reader: *Reader) u64 {
    const iterations = 2000;
    var graph: Graph = Graph{};
    var circular_buffer = CircularArray{};
    var prices_for_this_seller = DeltaSet{};
    var last_price: u8 = undefined;
    var secret = Secret{};

    while (reader.search_next_int(u64)) |initial| {
        secret.inner = initial;
        prices_for_this_seller.reset();
        circular_buffer.reset();
        last_price = secret.price();

        for (iterations) |_| {
            secret.cycle();
            const price = secret.price();

            const delta = @as(i8, @intCast(last_price)) - @as(i8, @intCast(price));
            circular_buffer.push(delta);

            if (circular_buffer.full()) {
                const deltas = circular_buffer.get();
                if (!prices_for_this_seller.get(deltas)) {
                    graph.insert(circular_buffer.get(), price);
                    prices_for_this_seller.set(deltas);
                }
            }

            last_price = price;
        }
    }

    return @as(u64, graph.max);
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
    try std.testing.expectEqual(2242, result);
}
