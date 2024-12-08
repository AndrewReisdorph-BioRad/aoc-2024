const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const benchmark = @import("utils/benchmark.zig");
const Stack = @import("utils/stack.zig").Stack;

const day = 7;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("../data/day{d}_small.txt", .{day});

const SimpleOperation = enum { add, multiply };
const Operation = enum { add, multiply, concat };

fn solve_two_operators(total: u64, values: []u16) bool {
    var operation_stack = Stack(SimpleOperation, 16).init();
    var total_stack = Stack(u64, 16).init();

    // choose multiplication as the default
    // if/when the result > total, replace the most recent multiplication with addition
    // then continue to multiply the next value until either the total matches OR using all addition
    var value_ptr: usize = 0;
    total_stack.push(@as(u64, values[value_ptr])) catch unreachable;
    value_ptr += 1;
    while (true) {
        //TODO if all multiplication is less than total, return false
        const current_total = total_stack.peek().?;
        if (current_total <= total and value_ptr < values.len) {
            const new_total = current_total * values[value_ptr];
            operation_stack.push(SimpleOperation.multiply) catch unreachable;
            total_stack.push(new_total) catch unreachable;
            value_ptr += 1;
        } else if (current_total == total) {
            return true;
        } else {
            // replace most recent * with +
            while (true) {
                if (operation_stack.size == 0) {
                    return false;
                } else {
                    if (operation_stack.peek() == SimpleOperation.multiply) {
                        // Remove top value
                        value_ptr -= 1;
                        _ = operation_stack.pop();
                        _ = total_stack.pop();
                        // Insert new value
                        const new_total = total_stack.peek().? + values[value_ptr];
                        value_ptr += 1;
                        operation_stack.push(SimpleOperation.add) catch unreachable;
                        total_stack.push(new_total) catch unreachable;
                        break;
                    } else {
                        // Remove + operation
                        value_ptr -= 1;
                        _ = operation_stack.pop();
                        _ = total_stack.pop();
                    }
                }
            }
        }
    }

    return false;
}

fn concat(a: u64, b: u64) u64 {
    var b_temp = b;
    var a_temp = a;
    while (b_temp >= 1) {
        a_temp *= 10;
        b_temp /= 10;
    }

    return a_temp + b;
}

test "concat" {
    const result = concat(81, 1);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 811);
}

fn solve_three_operators(total: u64, values: []u16) bool {
    var operation_stack = Stack(Operation, 16).init();
    var total_stack = Stack(u64, 16).init();

    // choose concatenation as the default
    // if/when the result > total, downgrade the most recent operation other than addition
    // then continue to concat the next value until either the total matches OR using all addition
    var value_ptr: usize = 0;
    total_stack.push(@as(u64, values[value_ptr])) catch unreachable;
    value_ptr += 1;
    while (true) {
        const current_total = total_stack.peek().?;
        if (current_total <= total and value_ptr < values.len) {
            const new_total = concat(current_total, values[value_ptr]);
            operation_stack.push(Operation.concat) catch unreachable;
            total_stack.push(new_total) catch unreachable;
            value_ptr += 1;
        } else if (current_total == total) {
            return true;
        } else {
            // downgrade the most recent operation "greater" than addition
            // || -> *
            //  * -> +
            while (true) {
                if (operation_stack.size == 0) {
                    return false;
                } else {
                    const operation = operation_stack.peek().?;
                    if (operation == Operation.concat) {
                        // Remove top value
                        value_ptr -= 1;
                        _ = operation_stack.pop();
                        _ = total_stack.pop();
                        // Insert new value
                        const new_total = total_stack.peek().? * values[value_ptr];
                        value_ptr += 1;
                        operation_stack.push(Operation.multiply) catch unreachable;
                        total_stack.push(new_total) catch unreachable;
                        break;
                    } else if (operation == Operation.multiply) {
                        // Remove top value
                        value_ptr -= 1;
                        _ = operation_stack.pop();
                        _ = total_stack.pop();
                        // Insert new value
                        const new_total = total_stack.peek().? + values[value_ptr];
                        value_ptr += 1;
                        operation_stack.push(Operation.add) catch unreachable;
                        total_stack.push(new_total) catch unreachable;
                        break;
                    } else {
                        // Remove + operation
                        value_ptr -= 1;
                        _ = operation_stack.pop();
                        _ = total_stack.pop();
                    }
                }
            }
        }
    }

    return false;
}

pub fn part_one(reader: *Reader) u128 {
    var sum: u128 = 0;

    while (true) {
        var values: [16]u16 = std.mem.zeroes([16]u16);
        // parse line
        const maybe_total = reader.next_int(u64, false);
        if (maybe_total == null) {
            break;
        }
        const total = maybe_total.?;
        _ = reader.next_char();
        _ = reader.next_char();
        const line = reader.next_line().?;
        var it = std.mem.split(u8, line, " ");
        var num_values: usize = 0;
        while (it.next()) |value| {
            values[num_values] = std.fmt.parseInt(u16, value, 10) catch unreachable;
            num_values += 1;
        }

        if (solve_two_operators(total, values[0..num_values])) {
            sum += @as(u128, total);
        }
    }

    return sum;
}

pub fn part_two(reader: *Reader) u128 {
    var sum: u128 = 0;

    while (true) {
        var values: [16]u16 = std.mem.zeroes([16]u16);
        // parse line
        const maybe_total = reader.next_int(u64, false);
        if (maybe_total == null) {
            break;
        }
        const total = maybe_total.?;
        _ = reader.next_char();
        _ = reader.next_char();
        const line = reader.next_line().?;
        var it = std.mem.split(u8, line, " ");
        var num_values: usize = 0;
        while (it.next()) |value| {
            values[num_values] = std.fmt.parseInt(u16, value, 10) catch unreachable;
            num_values += 1;
        }

        if (solve_three_operators(total, values[0..num_values])) {
            sum += @as(u128, total);
        }
    }

    return sum;
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
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 3749);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 3119088655389);
}

test "part 2 small" {
    std.debug.print("\n", .{});
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 11387);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 264184041398847);
}
