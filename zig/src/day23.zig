const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const benchmark = @import("utils/benchmark.zig");
const Bitfield = @import("utils/bitfield.zig").Bitfield;

const day = 23;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});

const Address = struct {
    const Self = @This();
    inner: [2]u8,
    pub fn from_chars(chars: [2]u8) Self {
        return Self{ .inner = .{ chars[0] - 97, chars[1] - 97 } };
    }
    pub fn from_usize(value: usize) Self {
        const char_a = value % 26;
        const char_b = (value - char_a) / 26;

        return Self{ .inner = .{ @as(u8, @intCast(char_a)), @as(u8, @intCast(char_b)) } };
    }
    pub fn as_u16(self: *const Self) u16 {
        return @as(u16, self.inner[0]) + @as(u16, self.inner[1]) * 26;
    }
    pub fn pretty(self: *const Self) [2]u8 {
        return .{ self.inner[0] + 97, self.inner[1] + 97 };
    }
};

pub fn get_triplet_id(a: Address, b: Address, c: Address) u64 {
    var buffer: [4]u16 = .{ a.as_u16(), b.as_u16(), c.as_u16(), 0 };

    if (buffer[0] > buffer[1]) {
        const temp = buffer[1];
        buffer[1] = buffer[0];
        buffer[0] = temp;
    }

    if (buffer[1] > buffer[2]) {
        const temp = buffer[2];
        buffer[2] = buffer[1];
        buffer[1] = temp;
    }

    if (buffer[0] > buffer[1]) {
        const temp = buffer[1];
        buffer[1] = buffer[0];
        buffer[0] = temp;
    }

    return std.mem.readInt(u64, @ptrCast(&buffer), std.builtin.Endian.little);
}

pub fn part_one(reader: *Reader) u64 {
    var connections: [26][26]Bitfield(26 * 26) = .{.{Bitfield(26 * 26){}} ** 26} ** 26;

    while (reader.next_char()) |first_byte| {
        const first_address = Address.from_chars(.{ first_byte, reader.next_char().? });
        // eat the dash
        _ = reader.next_char();
        const second_address = Address.from_chars(.{ reader.next_char().?, reader.next_char().? });

        connections[first_address.inner[0]][first_address.inner[1]].set(second_address.as_u16());
        connections[second_address.inner[0]][second_address.inner[1]].set(first_address.as_u16());

        // eat the new line
        _ = reader.next_char();
    }

    // For each A's connections B, check if any of B's connections C have a connection to A
    var found_triplets = std.AutoHashMap(u64, void).init(std.heap.page_allocator);
    defer found_triplets.deinit();
    var t_connections = &connections['t' - 97];
    for (0..26) |connection_idx| {
        const address_a = Address.from_chars(.{ 't', @as(u8, @intCast(connection_idx)) + 97 });
        const a_connections = &t_connections[connection_idx];
        if (a_connections.count < 2) {
            continue;
        }

        // For each connection of the test connection
        var a_connection_iter = a_connections.iter();
        while (a_connection_iter.next()) |id| {
            const address_b = Address.from_usize(id);

            var b_connections = &connections[address_b.inner[0]][address_b.inner[1]];
            var b_connection_iter = b_connections.iter();
            while (b_connection_iter.next()) |connection_c| {
                const address_c = Address.from_usize(connection_c);
                if (std.meta.eql(address_a, address_c)) {
                    continue;
                }

                const c_connections = &connections[address_c.inner[0]][address_c.inner[1]];
                if (c_connections.get(address_a.as_u16())) {

                    // Check if this triplet has been found
                    const key = get_triplet_id(address_a, address_b, address_c);
                    if (found_triplets.get(key) == null) {
                        found_triplets.put(key, {}) catch unreachable;
                    }
                }
            }
        }
    }

    return found_triplets.count();
}

pub fn read_connections(reader: *Reader, connections: *[26][26]Bitfield(26 * 26)) void {
    while (reader.next_char()) |first_byte| {
        const first_address = Address.from_chars(.{ first_byte, reader.next_char().? });
        // eat the dash
        _ = reader.next_char();
        const second_address = Address.from_chars(.{ reader.next_char().?, reader.next_char().? });

        connections[first_address.inner[0]][first_address.inner[1]].set(second_address.as_u16());
        connections[second_address.inner[0]][second_address.inner[1]].set(first_address.as_u16());

        // eat the new line
        _ = reader.next_char();
    }
}

pub fn sort_addr(_: void, a: [2]u8, b: [2]u8) bool {
    if (a[0] != b[0]) {
        return a[0] < b[0];
    }
    return a[1] < b[1];
}

pub fn part_two(reader: *Reader) std.ArrayList([2]u8) {
    var connections: [26][26]Bitfield(26 * 26) = .{.{Bitfield(26 * 26){}} ** 26} ** 26;
    read_connections(reader, &connections);

    var max_network_size: u32 = 0;
    var connected_peers = std.ArrayList([2]u8).init(std.heap.page_allocator);
    defer connected_peers.deinit();
    var max_connected_peers = std.ArrayList([2]u8).init(std.heap.page_allocator);

    for (0..26) |first_char| {
        for (0..26) |second_char| {
            const connection_a = &connections[first_char][second_char];
            const address_a = Address.from_chars(.{ @as(u8, @intCast(first_char)) + 97, @as(u8, @intCast(second_char)) + 97 });
            if (connection_a.count == 0) {
                continue;
            }

            var connection_a_iter = connection_a.iter();
            while (connection_a_iter.next()) |usize_addr| {
                // Determine the largest network possible that includes both connection_a and connection_b
                const address_b = Address.from_usize(usize_addr);

                const connection_b = &connections[address_b.inner[0]][address_b.inner[1]];
                var shared_connections = Bitfield(26 * 26).from_and(connection_a, connection_b);
                if (shared_connections.count < 2) {
                    continue;
                }

                const target_shared_subconnection_count: u32 = shared_connections.count;
                if (target_shared_subconnection_count <= max_network_size) {
                    continue;
                }

                connected_peers.clearRetainingCapacity();

                var shared_connection_iter = shared_connections.iter();
                while (shared_connection_iter.next()) |shared_connection| {
                    const shared_connection_addr = Address.from_usize(shared_connection);
                    const shared_connection_connections = &connections[shared_connection_addr.inner[0]][shared_connection_addr.inner[1]];
                    // how many shared connections are connected to one another?
                    var shared_connection_sub_iter = shared_connections.iter();
                    var shared_sub_connections: u32 = 0;
                    while (shared_connection_sub_iter.next()) |sub_shared_connection| {
                        if (std.meta.eql(shared_connection, sub_shared_connection)) {
                            continue;
                        }
                        if (shared_connection_connections.get(sub_shared_connection)) {
                            shared_sub_connections += 1;
                        }
                    }
                    if (shared_sub_connections == (target_shared_subconnection_count - 1)) {
                        connected_peers.append(shared_connection_addr.pretty()) catch unreachable;
                    }
                }

                if (connected_peers.items.len == target_shared_subconnection_count) {
                    max_network_size = target_shared_subconnection_count;
                    max_connected_peers.clearRetainingCapacity();
                    max_connected_peers.appendSlice(connected_peers.items) catch unreachable;
                    max_connected_peers.append(address_a.pretty()) catch unreachable;
                    max_connected_peers.append(address_b.pretty()) catch unreachable;
                }
            }
        }
    }

    std.mem.sort([2]u8, max_connected_peers.items, {}, sort_addr);

    return max_connected_peers;
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
            part_two(&reader).deinit();
        }
    }.run, .warm_up_iterations = 5 });
}

const sample_data =
    \\kh-tc
    \\qp-kh
    \\de-cg
    \\ka-co
    \\yn-aq
    \\qp-ub
    \\cg-tb
    \\vc-aq
    \\tb-ka
    \\wh-tc
    \\yn-cg
    \\kh-ub
    \\ta-co
    \\de-co
    \\tc-td
    \\tb-wq
    \\wh-td
    \\ta-ka
    \\td-qp
    \\aq-cg
    \\wq-ub
    \\ub-vc
    \\de-ta
    \\wq-aq
    \\wq-vc
    \\wh-yn
    \\ka-de
    \\kh-ta
    \\co-tc
    \\wh-qp
    \\tb-vc
    \\td-yn
;

test "part 1 small" {
    var reader = Reader.init(sample_data);
    const result = part_one(&reader);
    try std.testing.expectEqual(7, result);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    try std.testing.expectEqual(1400, result);
}

test "part 2 small" {
    var reader = Reader.init(sample_data);
    const result = part_two(&reader);
    const expected: []const [2]u8 = &.{ "co".*, "de".*, "ka".*, "ta".* };
    try std.testing.expect(std.mem.eql([2]u8, expected, result.items));
    result.deinit();
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    const expected: []const [2]u8 = &.{ "am".*, "bc".*, "cz".*, "dc".*, "gy".*, "hk".*, "li".*, "qf".*, "th".*, "tj".*, "wf".*, "xk".*, "xo".* };
    try std.testing.expect(std.mem.eql([2]u8, expected, result.items));
    result.deinit();
}
