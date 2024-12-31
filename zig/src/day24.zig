const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const SeekFrom = @import("utils/reader.zig").SeekFrom;
const benchmark = @import("utils/benchmark.zig");

const day = 24;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});

const Operation = enum {
    const Self = @This();
    and_,
    or_,
    xor,

    pub fn from_u8(value: u8) Self {
        return switch (value) {
            'A' => .and_,
            'O' => .or_,
            'X' => .xor,
            else => unreachable,
        };
    }
};

const Name = [3]u8;
const Relationship = struct { arg1: Name, arg2: Name, operation: Operation };

pub fn read_inputs(reader: *Reader, values: *std.AutoHashMap(Name, bool), relationships: *std.AutoHashMap(Name, Relationship)) void {
    var name_bufs: [3]Name = undefined;

    while (reader.next_char()) |next| {
        if (next == '\n') {
            break;
        }
        name_bufs[0][0] = next;
        name_bufs[0][1] = reader.next_char().?;
        name_bufs[0][2] = reader.next_char().?;
        // skip ": "
        reader.seek(SeekFrom.Current, 2);
        const value = reader.next_char().? == '1';

        values.put(name_bufs[0], value) catch unreachable;

        // eat new line
        _ = reader.next_char();
    }

    // read relationships
    while (reader.next_char()) |next| {
        // read first argument
        name_bufs[0][0] = next;
        name_bufs[0][1] = reader.next_char().?;
        name_bufs[0][2] = reader.next_char().?;

        // skip space
        _ = reader.next_char();

        // read operation
        const operation = Operation.from_u8(reader.next_char().?);
        if (operation == Operation.or_) {
            reader.seek(SeekFrom.Current, 2);
        } else {
            reader.seek(SeekFrom.Current, 3);
        }

        // read second argument
        name_bufs[1][0] = reader.next_char().?;
        name_bufs[1][1] = reader.next_char().?;
        name_bufs[1][2] = reader.next_char().?;

        // skip arrow
        reader.seek(SeekFrom.Current, 4);

        // read output
        name_bufs[2][0] = reader.next_char().?;
        name_bufs[2][1] = reader.next_char().?;
        name_bufs[2][2] = reader.next_char().?;

        // update relationships
        relationships.put(name_bufs[2], Relationship{ .arg1 = name_bufs[0], .arg2 = name_bufs[1], .operation = operation }) catch unreachable;

        // eat newline
        _ = reader.next_char();
    }
}

pub fn part_one(reader: *Reader) u64 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var values = std.AutoHashMap(Name, bool).init(allocator);
    var relationships = std.AutoHashMap(Name, Relationship).init(allocator);

    read_inputs(reader, &values, &relationships);

    var got_new_value = true;

    var z: u64 = 0;

    while (got_new_value == true) {
        got_new_value = false;
        var relationship_iter = relationships.iterator();
        while (relationship_iter.next()) |relationship| {
            // skip if we already have a vlue for this output
            if (values.get(relationship.key_ptr.*) != null) {
                continue;
            }

            const arg1_value = values.get(relationship.value_ptr.arg1);
            const arg2_value = values.get(relationship.value_ptr.arg2);

            // skip if we have incomplete information
            if (arg1_value == null or arg2_value == null) {
                continue;
            }

            const value = switch (relationship.value_ptr.operation) {
                .and_ => @intFromBool(arg1_value.?) & @intFromBool(arg2_value.?),
                .or_ => @intFromBool(arg1_value.?) | @intFromBool(arg2_value.?),
                .xor => @intFromBool(arg1_value.?) ^ @intFromBool(arg2_value.?),
            };

            values.put(relationship.key_ptr.*, value == 1) catch unreachable;

            got_new_value = true;

            if (value == 1 and relationship.key_ptr[0] == 'z') {
                const bit: usize = (@as(usize, relationship.key_ptr[1]) - 48) * 10 + (@as(usize, relationship.key_ptr[2]) - 48);
                z |= @intCast(@as(u64, 1) << @intCast(bit));
            }
        }
    }

    return z;
}

pub fn solve(values: *std.AutoHashMap(Name, bool), relationships: *std.AutoHashMap(Name, Relationship)) void {
    var got_new_value = true;
    while (got_new_value == true) {
        got_new_value = false;
        var relationship_iter = relationships.iterator();
        while (relationship_iter.next()) |relationship| {
            // skip if we already have a vlue for this output
            if (values.get(relationship.key_ptr.*) != null) {
                continue;
            }

            const arg1_value = values.get(relationship.value_ptr.arg1);
            const arg2_value = values.get(relationship.value_ptr.arg2);

            // skip if we have incomplete information
            if (arg1_value == null or arg2_value == null) {
                continue;
            }

            const value = switch (relationship.value_ptr.operation) {
                .and_ => @intFromBool(arg1_value.?) & @intFromBool(arg2_value.?),
                .or_ => @intFromBool(arg1_value.?) | @intFromBool(arg2_value.?),
                .xor => @intFromBool(arg1_value.?) ^ @intFromBool(arg2_value.?),
            };

            values.put(relationship.key_ptr.*, value == 1) catch unreachable;

            got_new_value = true;
        }
    }
}

pub fn get_xyz(char: u8, values: *std.AutoHashMap(Name, bool)) u64 {
    var value_name: Name = .{ char, '0', '0' };
    var bit: usize = 0;
    var primary: u64 = 0;
    while (true) {
        value_name[1] = @as(u8, @intCast((bit / 10))) + 48;
        value_name[2] = @as(u8, @intCast((bit % 10))) + 48;

        if (values.get(value_name)) |value| {
            if (value) {
                primary |= @intCast(@as(u64, 1) << @intCast(bit));
            }
        } else {
            break;
        }

        bit += 1;
    }
    return primary;
}

const SwapIdxIter = struct {
    const Self = @This();
    total: usize,
    first: usize = 0,
    second: usize = 1,
    pub fn next(self: *Self) ?[2]usize {
        if (self.second == self.total) {
            self.first += 1;
            self.second = self.first + 1;
        }

        if (self.second >= self.total) {
            return null;
        }

        const next_idxs = .{ self.first, self.second };
        self.second += 1;
        return next_idxs;
    }
};

test "swap iter" {
    var swap_iter = SwapIdxIter{ .total = 5 };
    while (swap_iter.next()) |next| {
        std.debug.print("{any}\n", .{next});
    }
}

pub fn part_two(reader: *Reader) u64 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var values = std.AutoHashMap(Name, bool).init(allocator);
    var relationships = std.AutoHashMap(Name, Relationship).init(allocator);

    read_inputs(reader, &values, &relationships);
    const original_values = values.clone() catch unreachable;

    const x = get_xyz('x', &values);
    const y = get_xyz('y', &values);
    const expected_z = x + y;

    solve(&values, &relationships);

    const current_z = get_xyz('z', &values);

    // Only swaps of different values can change the final output
    var output_iter = values.iterator();
    var output_names_0 = std.ArrayList(Name).init(allocator);
    var output_names_1 = std.ArrayList(Name).init(allocator);

    while (output_iter.next()) |entry| {
        if (entry.key_ptr[0] == 'x' or entry.key_ptr[0] == 'y') {
            continue;
        }
        if (entry.value_ptr.*) {
            output_names_1.append(entry.key_ptr.*) catch unreachable;
        } else {
            output_names_0.append(entry.key_ptr.*) catch unreachable;
        }
    }
    std.debug.print("x: {d} y: {d}\n", .{ x, y });
    std.debug.print("Expected z = {d}\n", .{expected_z});

    // var swap_iter = SwapIdxIter{ .total = output_names.items.len };
    // while (swap_iter.next()) |swap| {
    //     var swapped_relationships = relationships.clone() catch unreachable;
    //     defer swapped_relationships.deinit();

    //     const swap_name_a = output_names.items[swap[0]];
    //     const swap_name_b = output_names.items[swap[1]];

    //     const temp = swapped_relationships.get(swap_name_b).?;
    //     swapped_relationships.put(swap_name_b, swapped_relationships.get(swap_name_a).?) catch unreachable;
    //     swapped_relationships.put(swap_name_a, temp) catch unreachable;

    //     var values_copy = values.clone() catch unreachable;
    //     defer values_copy.deinit();
    //     solve(&values_copy, &swapped_relationships);
    //     const new_z = get_xyz('z', &values_copy);

    //     if (bit_diff_count(expected_z, new_z) == 1) {
    //         std.debug.print("Swapping {s} and {s} changes 1 bit in z\n{b}  {b}\n\n", .{ swap_name_a, swap_name_b, expected_z, new_z });
    //     }
    // }

    var swaps = std.ArrayList(Name).init(allocator);
    _ = solve_with_n_swaps(&original_values, &relationships, 4, output_names_1.items, output_names_0.items, current_z, expected_z, &swaps);

    std.debug.print("Ended with swaps: {s}\n", .{swaps.items});

    return 0;
}

fn bit_diff_count(a: u64, b: u64) usize {
    var mask: u64 = 1;
    var different_bit_count: usize = 0;
    for (0..(@sizeOf(u64) * std.mem.byte_size_in_bits)) |_| {
        if ((a & mask) != (b & mask)) {
            different_bit_count += 1;
        }
        mask <<= 2;
    }
    return different_bit_count;
}

pub fn solve_with_n_swaps(values: *const std.AutoHashMap(Name, bool), relationships: *std.AutoHashMap(Name, Relationship), n: u8, ones: []Name, zeroes: []Name, current_z: u64, expected_z: u64, swaps: *std.ArrayList(Name)) bool {
    if (n == 0) {
        var values_copy = values.clone() catch unreachable;
        defer values_copy.deinit();
        solve(&values_copy, relationships);
        const actual_z = get_xyz('z', &values_copy);
        if (expected_z == actual_z) {
            std.debug.print("Found solution: {s}\n", .{swaps.items});
        }
        // std.debug.print("Checking swaps: {s}\nz = {d}\n", .{ swaps.items, actual_z });
        return expected_z == actual_z;
    }

    for (ones) |one_name| {
        for (zeroes) |zero_name| {
            // Swap a and b
            //TODO: Maybe we don't need to allocate here and can just swap back?
            var swapped_relationships = relationships.clone() catch unreachable;
            defer swapped_relationships.deinit();

            const temp = swapped_relationships.get(one_name).?;
            swapped_relationships.put(one_name, swapped_relationships.get(zero_name).?) catch unreachable;
            swapped_relationships.put(zero_name, temp) catch unreachable;

            var values_copy = values.clone() catch unreachable;
            defer values_copy.deinit();
            solve(&values_copy, &swapped_relationships);

            // If this swap didn't change the overvall value don't use it
            const new_z = get_xyz('z', &values_copy);
            if (new_z == current_z) {
                // std.debug.print("no change\n", .{});
                continue;
            }

            var output_iter = values_copy.iterator();
            var output_names_0 = std.ArrayList(Name).init(std.heap.page_allocator);
            defer output_names_0.deinit();
            var output_names_1 = std.ArrayList(Name).init(std.heap.page_allocator);
            defer output_names_1.deinit();

            while (output_iter.next()) |entry| {
                if (entry.key_ptr[0] == 'x' or entry.key_ptr[0] == 'y' or std.meta.eql(entry.key_ptr.*, one_name) or std.meta.eql(entry.key_ptr.*, zero_name)) {
                    continue;
                }
                var part_of_existing_swaps = false;
                for (swaps.items) |swap_name| {
                    if (std.meta.eql(entry.key_ptr.*, swap_name)) {
                        part_of_existing_swaps = true;
                        break;
                    }
                }
                // TODO: continue with named loop
                if (part_of_existing_swaps) {
                    continue;
                }
                if (entry.value_ptr.*) {
                    output_names_1.append(entry.key_ptr.*) catch unreachable;
                } else {
                    output_names_0.append(entry.key_ptr.*) catch unreachable;
                }
            }

            var new_swaps = swaps.clone() catch unreachable;
            defer new_swaps.deinit();
            new_swaps.append(one_name) catch unreachable;
            new_swaps.append(zero_name) catch unreachable;

            if (solve_with_n_swaps(values, &swapped_relationships, n - 1, output_names_1.items, output_names_0.items, new_z, expected_z, &new_swaps)) {
                swaps.append(one_name) catch unreachable;
                swaps.append(zero_name) catch unreachable;
                return true;
            }
        }
    }

    return false;
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

test "part 1 small" {
    var reader = Reader.init(
        \\x00: 1
        \\x01: 0
        \\x02: 1
        \\x03: 1
        \\x04: 0
        \\y00: 1
        \\y01: 1
        \\y02: 1
        \\y03: 1
        \\y04: 1
        \\
        \\ntg XOR fgs -> mjb
        \\y02 OR x01 -> tnw
        \\kwq OR kpj -> z05
        \\x00 OR x03 -> fst
        \\tgd XOR rvg -> z01
        \\vdt OR tnw -> bfw
        \\bfw AND frj -> z10
        \\ffh OR nrd -> bqk
        \\y00 AND y03 -> djm
        \\y03 OR y00 -> psh
        \\bqk OR frj -> z08
        \\tnw OR fst -> frj
        \\gnj AND tgd -> z11
        \\bfw XOR mjb -> z00
        \\x03 OR x00 -> vdt
        \\gnj AND wpb -> z02
        \\x04 AND y00 -> kjc
        \\djm OR pbm -> qhw
        \\nrd AND vdt -> hwm
        \\kjc AND fst -> rvg
        \\y04 OR y02 -> fgs
        \\y01 AND x02 -> pbm
        \\ntg OR kjc -> kwq
        \\psh XOR fgs -> tgd
        \\qhw XOR tgd -> z09
        \\pbm OR djm -> kpj
        \\x03 XOR y03 -> ffh
        \\x00 XOR y04 -> ntg
        \\bfw OR bqk -> z06
        \\nrd XOR fgs -> wpb
        \\frj XOR qhw -> z04
        \\bqk OR frj -> z07
        \\y03 OR x01 -> nrd
        \\hwm AND bqk -> z03
        \\tgd XOR rvg -> z12
        \\tnw OR pbm -> gnj
    );
    const result = part_one(&reader);
    try std.testing.expectEqual(2024, result);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    try std.testing.expectEqual(53755311654662, result);
}

test "part 2 small" {
    var reader = Reader.init(
        \\x00: 0
        \\x01: 1
        \\x02: 0
        \\x03: 1
        \\x04: 0
        \\x05: 1
        \\y00: 0
        \\y01: 0
        \\y02: 1
        \\y03: 1
        \\y04: 0
        \\y05: 1
        \\
        \\x00 AND y00 -> z05
        \\x01 AND y01 -> z02
        \\x02 AND y02 -> z01
        \\x03 AND y03 -> z03
        \\x04 AND y04 -> z04
        \\x05 AND y05 -> z00
    );
    const result = part_two(&reader);
    try std.testing.expectEqual(1, result);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    try std.testing.expectEqual(1, result);
}
