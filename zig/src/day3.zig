const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const SeekFrom = @import("utils/reader.zig").SeekFrom;
const benchmark = @import("utils/benchmark.zig");

const day = 3;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("../data/day{d}_small.txt", .{day});
const alt_small_data_path = std.fmt.comptimePrint("../data/day{d}_small_b.txt", .{day});

pub fn part_one(reader: *Reader) u64 {
    var sum: u64 = 0;

    while (reader.seek_to_next_substr("mul(")) |_| {
        reader.seek(SeekFrom.Current, 4);
        var op1: u32 = 0;
        var op2: u32 = 0;
        if (reader.next_u32(false)) |operand| {
            op1 = operand;
        } else {
            continue;
        }

        if (reader.next_char() != ',') {
            continue;
        }

        if (reader.next_u32(false)) |operand| {
            op2 = operand;
        } else {
            continue;
        }

        if (reader.next_char() != ')') {
            continue;
        }

        sum += op1 * op2;
    }

    return sum;
}

const Token = union(enum) {
    garbage,
    number: u32,
    comma,
    mul,
    do,
    dont,
    leftParen,
    rightParen,
};

const Tokenizer = struct {
    reader: *Reader,
    const Self = @This();

    pub fn init(reader: *Reader) Self {
        return Self{ .reader = reader };
    }

    pub fn next(self: *Self) ?Token {
        var buffer: [16:0]u8 = undefined;
        var current_token_size: u32 = 0;

        while (self.reader.next_char()) |c| {
            if (current_token_size == 0) {
                if (std.ascii.isDigit(c)) {
                    self.reader.seek(SeekFrom.Current, -1);
                    const number = self.reader.next_u32(false).?;
                    return Token{ .number = number };
                } else {
                    switch (c) {
                        'm' => buffer[0] = 'm',
                        'd' => buffer[0] = 'd',
                        ',' => return Token{ .comma = {} },
                        '(' => return Token{ .leftParen = {} },
                        ')' => return Token{ .rightParen = {} },
                        else => return Token{ .garbage = {} },
                    }
                }
                current_token_size += 1;
            } else {
                if (buffer[0] == 'm') { // Check for continuation of "mul"
                    if (current_token_size == 1 and c == 'u') {
                        buffer[1] = 'u';
                    } else if (current_token_size == 2 and c == 'l') {
                        return Token{ .mul = {} };
                    } else {
                        return Token{ .garbage = {} };
                    }
                } else if (buffer[0] == 'd') { // Check for continuation of "do" or "don't"
                    if (current_token_size == 1 and c == 'o') {
                        buffer[1] = 'o';
                    } else if (current_token_size == 2) {
                        if (c == 'n') {
                            buffer[2] = 'n';
                        } else {
                            // Found "do" + some other character besides 'n', return a do token and then reprocess that character
                            self.reader.seek(SeekFrom.Current, -1);
                            return Token{ .do = {} };
                        }
                    } else if (current_token_size == 3 and c == '\'') {
                        buffer[3] = '\'';
                    } else if (current_token_size == 4 and c == 't') {
                        return Token{ .dont = {} };
                    } else {
                        return Token{ .garbage = {} };
                    }
                }
                current_token_size += 1;
            }
        }

        return null;
    }
};

pub fn part_two(reader: *Reader) u64 {
    var sum: u64 = 0;

    var tokenizer = Tokenizer.init(reader);

    const FunctionName = enum { mul, do, dont };
    const State = enum { garbage, function, function_operands };

    const max_operands = 2;
    var operands: [max_operands:0]u32 = undefined;
    var num_operands: u8 = 0;
    var current_function: FunctionName = FunctionName.mul;
    var state = State.garbage;
    var expecting_comma: bool = false;

    var mul_enabled = true;

    while (tokenizer.next()) |token| {
        switch (state) {
            .garbage => {
                switch (token) {
                    .mul => {
                        state = State.function;
                        current_function = FunctionName.mul;
                    },
                    .do => {
                        state = State.function;
                        current_function = FunctionName.do;
                    },
                    .dont => {
                        state = State.function;
                        current_function = FunctionName.dont;
                    },
                    else => {},
                }
            },
            .function => {
                switch (token) {
                    .leftParen => {
                        state = State.function_operands;
                        num_operands = 0;
                        expecting_comma = false;
                    },
                    else => {
                        state = State.garbage;
                    },
                }
            },
            .function_operands => {
                switch (token) {
                    .rightParen => {
                        switch (current_function) {
                            .mul => {
                                if (mul_enabled and num_operands == 2) {
                                    sum += operands[0] * operands[1];
                                }
                            },
                            .do => {
                                if (num_operands == 0) {
                                    mul_enabled = true;
                                }
                            },
                            .dont => {
                                if (num_operands == 0) {
                                    mul_enabled = false;
                                }
                            },
                        }
                        state = State.garbage;
                    },
                    .number => {
                        if (expecting_comma or num_operands > max_operands) {
                            state = State.garbage;
                        } else {
                            operands[num_operands] = token.number;
                            num_operands += 1;
                            expecting_comma = true;
                        }
                    },
                    .comma => {
                        if (expecting_comma) {
                            expecting_comma = false;
                        } else {
                            state = State.garbage;
                        }
                    },
                    else => {
                        state = State.garbage;
                    },
                }
            },
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
    try std.testing.expect(result == 2);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 359);
}

test "part 2 small" {
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 4);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 418);
}
