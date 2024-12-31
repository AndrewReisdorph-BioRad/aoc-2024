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
    pub fn as_u8(self: *const Self) u8 {
        return switch (self.*) {
            .and_ => '&',
            .or_ => '|',
            .xor => '^',
        };
    }
};

const Name = [3]u8;
fn build_name(char: u8, bit: usize) Name {
    return Name{ char, @as(u8, @intCast(((bit - (bit % 10)) / 10) + 48)), @as(u8, @intCast((bit % 10) + 48)) };
}
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

pub fn solve(values: *std.AutoHashMap(Name, bool), relationships: *std.AutoHashMap(Name, Relationship)) u64 {
    var z: u64 = 0;

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

            if (value == 1 and relationship.key_ptr[0] == 'z') {
                const bit: usize = (@as(usize, relationship.key_ptr[1]) - 48) * 10 + (@as(usize, relationship.key_ptr[2]) - 48);
                z |= @intCast(@as(u64, 1) << @intCast(bit));
            }
        }
    }

    return z;
}

fn set_default_values(values: *std.AutoHashMap(Name, bool)) void {
    values.clearRetainingCapacity();
    for (0..45) |i| {
        var key = Name{ 'x', @as(u8, @intCast(((i - (i % 10)) / 10) + 48)), @as(u8, @intCast((i % 10) + 48)) };
        values.put(key, false) catch unreachable;
        key[0] = 'y';
        values.put(key, false) catch unreachable;
    }
}

fn nameLessThan(_: void, lhs: Name, rhs: Name) bool {
    return std.mem.order(u8, &lhs, &rhs) == .lt;
}

pub fn part_two(reader: *Reader) [8]Name {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var values = std.AutoHashMap(Name, bool).init(allocator);
    var relationships = std.AutoHashMap(Name, Relationship).init(allocator);
    //TODO: We don't care about values here
    read_inputs(reader, &values, &relationships);

    var test_values = std.AutoHashMap(Name, bool).init(allocator);
    var incorrect_bits: [4]usize = undefined;
    var num_incorrect_bits: usize = 0;
    for (0..45) |i| {
        set_default_values(&test_values);
        const key = build_name('y', i);
        test_values.put(key, true) catch unreachable;
        const expected_z: u64 = @as(u64, 1) << @intCast(i);
        const test_z = solve(&test_values, &relationships);
        if (test_z != expected_z) {
            incorrect_bits[num_incorrect_bits] = i;
            num_incorrect_bits += 1;
        }
    }

    var swaps: [8]Name = undefined;
    var swap_idx: usize = 0;

    // Search for invalid circuitry based on known structure of adder circuit
    for (incorrect_bits) |bit| {
        const name = build_name('z', bit);
        const gate = relationships.get(name).?;
        if (gate.operation == Operation.xor) {
            const input_1_gate = relationships.get(gate.arg1).?;
            const input_2_gate = relationships.get(gate.arg2).?;
            var problem_gate_name: Name = undefined;
            var expected_operation: Operation = undefined;
            if (input_1_gate.operation == .or_ or input_1_gate.operation == .xor) {
                if (input_2_gate.operation == .or_ or input_2_gate.operation == .xor) {
                    @panic("Unhandled!");
                }
                expected_operation = if (input_1_gate.operation == .or_) .xor else .or_;
                problem_gate_name = gate.arg2;
            } else {
                expected_operation = if (input_2_gate.operation == .or_) .xor else .or_;
                problem_gate_name = gate.arg1;
            }
            if (expected_operation == .xor) {
                // Find the gate that XOR's the x and y values for this z bit
                const x_gate_name = build_name('x', bit);
                const y_gate_name = build_name('y', bit);
                var target_gate: Relationship = undefined;
                var target_gate_name: Name = undefined;

                var gate_iter = relationships.iterator();
                while (gate_iter.next()) |g| {
                    if ((std.meta.eql(g.value_ptr.arg1, x_gate_name) or std.meta.eql(g.value_ptr.arg2, x_gate_name)) and
                        (std.meta.eql(g.value_ptr.arg1, y_gate_name) or std.meta.eql(g.value_ptr.arg2, y_gate_name)) and
                        g.value_ptr.operation == .xor)
                    {
                        target_gate = g.value_ptr.*;
                        target_gate_name = g.key_ptr.*;
                        break;
                    }
                }
                swaps[swap_idx] = problem_gate_name;
                swaps[swap_idx + 1] = target_gate_name;
                swap_idx += 2;
            } else {
                @panic("Unhandled!");
            }
        } else {
            // We expected to find an XOR but didn't find one
            // Swap must occur with this gate and an XOR gate
            const x_gate_name = build_name('x', bit);
            const y_gate_name = build_name('y', bit);
            var target_gate: Relationship = undefined;
            var target_gate_name: Name = undefined;
            var gate_iter = relationships.iterator();
            while (gate_iter.next()) |g| {
                if ((std.meta.eql(g.value_ptr.arg1, x_gate_name) or std.meta.eql(g.value_ptr.arg2, x_gate_name)) and
                    (std.meta.eql(g.value_ptr.arg1, y_gate_name) or std.meta.eql(g.value_ptr.arg2, y_gate_name)) and
                    g.value_ptr.operation == .xor)
                {
                    target_gate = g.value_ptr.*;
                    target_gate_name = g.key_ptr.*;
                    break;
                }
            }
            gate_iter = relationships.iterator();
            while (gate_iter.next()) |g| {
                if ((std.meta.eql(g.value_ptr.arg1, target_gate_name) or std.meta.eql(g.value_ptr.arg2, target_gate_name)) and
                    g.value_ptr.operation == .xor)
                {
                    target_gate = g.value_ptr.*;
                    target_gate_name = g.key_ptr.*;
                    break;
                }
            }
            swaps[swap_idx] = name;
            swaps[swap_idx + 1] = target_gate_name;
            swap_idx += 2;
        }
    }

    std.mem.sort(Name, &swaps, {}, nameLessThan);

    return swaps;
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

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    const expected = .{ Name{ 'd', 'k', 'r' }, Name{ 'g', 'g', 'k' }, Name{ 'h', 'h', 'h' }, Name{ 'h', 't', 'p' }, Name{ 'r', 'h', 'v' }, Name{ 'z', '0', '5' }, Name{ 'z', '1', '5' }, Name{ 'z', '2', '0' } };
    try std.testing.expectEqual(expected, result);
}
