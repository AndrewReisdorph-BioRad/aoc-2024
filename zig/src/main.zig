const std = @import("std");

pub fn main() !void {
    // var reader = @import("reader.zig").Reader.from_comptime_path("./data/day1.txt");
    @import("day1.zig").day1_part1_benchmark();
    // const result = @import("day1.zig").part_two(&reader);
    // std.debug.print("Result: {d}\n", .{result});
}
