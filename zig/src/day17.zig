const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const benchmark = @import("utils/benchmark.zig");
const Stack = @import("utils/stack.zig").Stack;

const day = 17;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("../data/day{d}_small.txt", .{day});
const small_b_data_path = std.fmt.comptimePrint("../data/day{d}_small_b.txt", .{day});

const max_rom_size = 10;
const max_output_buffer_size = 20;

const Opcode = enum(u3) { adv = 0, bxl = 1, bst = 2, jnz = 3, bxc = 4, out = 5, bdv = 6, cdv = 7 };

const Instruction = struct {
    opcode: Opcode,
    operand: u3,
};

const Computer = struct {
    const Self = @This();
    const A = 0;
    const B = 1;
    const C = 2;
    registers: [3]u64 = undefined,
    output_buffer: [max_output_buffer_size]u8 = undefined,
    program: [max_rom_size]Instruction = undefined,
    program_counter: usize = 0,
    program_size: usize = 0,
    output_buffer_size: usize = 0,
    pub fn init(reader: *Reader) Self {
        var new = Self{};
        new.registers[0] = reader.search_next_int(u64).?;
        new.registers[1] = reader.search_next_int(u64).?;
        new.registers[2] = reader.search_next_int(u64).?;

        while (reader.search_next_int(u8)) |opcode| {
            new.program[new.program_size].opcode = @enumFromInt(opcode);
            new.program[new.program_size].operand = @as(u3, @intCast(reader.search_next_int(u8).?));
            new.program_size += 1;
        }

        return new;
    }

    pub fn run(self: *Self) void {
        while (self.program_counter < self.program_size) {
            // fetch
            const instruction = self.program[self.program_counter];
            // execute
            self.exec(instruction);
        }
    }

    pub fn reset(self: *Self) void {
        @memset(&self.registers, 0);
        self.program_counter = 0;
        self.output_buffer_size = 0;
    }

    fn combo(self: *Self, value: u3) u64 {
        if (value <= 3) {
            return @as(u64, value);
        }
        return self.registers[value - 4];
    }

    fn exec(self: *Self, instruction: Instruction) void {
        var increment_pc = true;
        switch (instruction.opcode) {
            // The adv instruction (opcode 0) performs division. The numerator is the value in the A register.
            // The denominator is found by raising 2 to the power of the instruction's combo operand. (So, an operand
            // of 2 would divide A by 4 (2^2); an operand of 5 would divide A by 2^B.) The result of the division
            // operation is truncated to an integer and then written to the A register.
            .adv => {
                self.registers[A] /= std.math.pow(u64, 2, self.combo(instruction.operand));
            },
            // The bxl instruction (opcode 1) calculates the bitwise XOR of register B and the instruction's literal
            // operand, then stores the result in register B.
            .bxl => {
                self.registers[B] ^= @as(u64, instruction.operand);
            },
            // The bst instruction (opcode 2) calculates the value of its combo operand modulo 8 (thereby keeping
            // only its lowest 3 bits), then writes that value to the B register.
            .bst => {
                self.registers[B] = self.combo(instruction.operand) & 7;
            },
            // The jnz instruction (opcode 3) does nothing if the A register is 0. However, if the A register is not
            // zero, it jumps by setting the instruction pointer to the value of its literal operand; if this
            // instruction jumps, the instruction pointer is not increased by 2 after this instruction.
            .jnz => {
                if (self.registers[A] != 0) {
                    self.program_counter = instruction.operand / 2;
                    increment_pc = false;
                }
            },
            // The bxc instruction (opcode 4) calculates the bitwise XOR of register B and register C, then stores
            // the result in register B. (For legacy reasons, this instruction reads an operand but ignores it.)
            .bxc => {
                self.registers[B] ^= self.registers[C];
            },
            // The out instruction (opcode 5) calculates the value of its combo operand modulo 8, then outputs that
            // value. (If a program outputs multiple values, they are separated by commas.)
            .out => {
                self.output_buffer[self.output_buffer_size] = @as(u8, @intCast(self.combo(instruction.operand) & 7));
                self.output_buffer_size += 1;
            },
            // THIS INSTRUCTION DOES NOT APPEAR IN ANY INPUT DATA.
            // The bdv instruction (opcode 6) works exactly like the adv instruction except that the result is stored
            // in the B register. (The numerator is still read from the A register.)
            // .bdv => {
            //     // const denominator = std.math.pow(u64, 2, self.combo(instruction.operand));
            //     // self.registers[B] = self.registers[A] / denominator;
            // },
            // The cdv instruction (opcode 7) works exactly like the adv instruction except that the result is stored
            // in the C register. (The numerator is still read from the A register.)
            .cdv => {
                const denominator = std.math.pow(u64, 2, self.combo(instruction.operand));
                self.registers[C] = self.registers[A] / denominator;
            },
            else => {
                unreachable;
            },
        }

        if (increment_pc) {
            self.program_counter += 1;
        }
    }

    pub fn print_output_buffer(self: *const Self) void {
        for (0..self.output_buffer_size) |i| {
            if (i > 0) {
                std.debug.print(",", .{});
            }
            std.debug.print("{d}", .{self.output_buffer[i]});
        }
    }

    pub fn compare_output_buffer_to_program(self: *const Self) u8 {
        if (self.output_buffer_size > (self.program_size * 2)) {
            return 0;
        }
        var buffer_idx: usize = 0;
        var matching_bytes: u8 = 0;
        while (buffer_idx < self.output_buffer_size) {
            const instruction = self.program[buffer_idx / 2];
            if (self.output_buffer[buffer_idx] == @intFromEnum(instruction.opcode)) {
                matching_bytes += 1;
            } else {
                break;
            }
            if (self.output_buffer[buffer_idx + 1] == @as(u8, instruction.operand)) {
                matching_bytes += 1;
            } else {
                break;
            }
            buffer_idx += 2;
        }
        return matching_bytes;
    }
};

pub fn part_one(reader: *Reader) Computer {
    var computer = Computer.init(reader);
    computer.run();
    return computer;
}

pub fn part_two(reader: *Reader) u64 {
    var computer = Computer.init(reader);

    const TestValue = struct {
        shift_bytes: u8,
        value: u64,
        matching_bytes: u8,
    };

    var test_stack = Stack(TestValue, 319).init();
    test_stack.push(TestValue{ .shift_bytes = 0, .value = 0, .matching_bytes = 0 }) catch unreachable;

    const program_byte_length = computer.program_size * 2;
    var test_byte: u64 = 0;
    while (test_stack.pop()) |test_value| {
        test_byte = 255;
        while (test_byte > 0) {
            const a = (test_byte << @intCast(test_value.shift_bytes * 8)) | test_value.value;
            computer.reset();
            computer.registers[Computer.A] = a;
            computer.run();
            const matching_bytes = computer.compare_output_buffer_to_program();
            if (matching_bytes > test_value.matching_bytes) {
                if (matching_bytes == program_byte_length) {
                    return a;
                }
                test_stack.push(TestValue{ .shift_bytes = test_value.shift_bytes + 1, .value = a, .matching_bytes = matching_bytes }) catch unreachable;
            }
            test_byte -= 1;
        }
    }

    unreachable;
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
        \\Register A: 729
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,1,5,4,3,0
    );

    const result = part_one(&reader);
    const expected: []const u8 = &.{ 4, 6, 3, 5, 6, 3, 5, 2, 1, 0 };
    try std.testing.expect(std.mem.eql(u8, expected, result.output_buffer[0..result.output_buffer_size]));
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    const expected: []const u8 = &.{ 3, 6, 7, 0, 5, 7, 3, 1, 4 };
    try std.testing.expect(std.mem.eql(u8, expected, result.output_buffer[0..result.output_buffer_size]));
}

test "part 2 small" {
    var reader = Reader.init(
        \\Register A: 2024
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,3,5,4,3,0
    );
    const result = part_two(&reader);
    try std.testing.expectEqual(117440, result);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    try std.testing.expectEqual(164278496489149, result);
}
