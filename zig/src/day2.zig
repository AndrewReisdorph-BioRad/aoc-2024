const std = @import("std");
const Reader = @import("reader.zig").Reader;
const benchmark = @import("benchmark.zig");

const day = 2;
const data_path = std.fmt.comptimePrint("./data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("./data/day{d}_small.txt", .{day});

const Report = std.ArrayList(u32);

fn parse_report(report: []const u8) Report {
    var levels = Report.init(std.heap.page_allocator);
    var it = std.mem.splitScalar(u8, report, ' ');
    while (it.next()) |level| {
        levels.append(std.fmt.parseInt(u32, level, 10) catch unreachable) catch unreachable;
    }
    return levels;
}

fn report_is_safe(report: *const Report) bool {
    var last_delta: i3 = 0;
    for (1..report.items.len) |i| {
        const difference: i64 = @as(i64, report.items[i]) - @as(i64, report.items[i - 1]);
        if (difference == 0) {
            return false;
        }
        const delta: i3 = if (difference > 0) 1 else -1;
        // check for direction change
        if (last_delta != 0 and last_delta != delta) {
            return false;
        }
        last_delta = delta;

        if (@abs(difference) > 3) {
            return false;
        }
    }

    return true;
}

fn report_is_safe_with_problem_dampener_naive(report: *const Report) bool {
    if (report_is_safe(report)) {
        return true;
    }

    // Allocate space for new report
    var dampened_report = Report.initCapacity(std.heap.page_allocator, report.items.len - 1) catch unreachable;
    defer dampened_report.deinit();
    // Create an alternate version of the report with an index removed
    // Check if the new report is valid
    // If not move on to the next inde
    for (0..report.items.len) |i| {
        // Copy report items except the item at index i
        dampened_report.clearRetainingCapacity();
        dampened_report.appendSlice(report.items[0..i]) catch unreachable;
        dampened_report.appendSlice(report.items[i + 1 ..]) catch unreachable;

        if (report_is_safe(&dampened_report)) {
            return true;
        }
    }

    return false;
}

pub fn part_one(reader: *Reader) u64 {
    var safe_reports: u64 = 0;

    while (reader.next_line()) |line| {
        const report = parse_report(line);
        defer report.deinit();

        if (report_is_safe(&report)) {
            safe_reports += 1;
        }
    }

    return safe_reports;
}

pub fn part_two(reader: *Reader) u64 {
    var safe_reports: u64 = 0;

    while (reader.next_line()) |line| {
        const report = parse_report(line);
        defer report.deinit();

        if (report_is_safe_with_problem_dampener_naive(&report)) {
            safe_reports += 1;
        }
    }

    return safe_reports;
}

pub fn part1_benchmark() void {
    benchmark.benchmark(benchmark.BenchmarkOptions{ .func = struct {
        fn run() void {
            var reader = Reader.from_comptime_path(data_path);
            _ = part_one(&reader);
        }
    }.run, .warm_up_iterations = 5, .iterations = 100 });
}

pub fn part2_benchmark() void {
    benchmark.benchmark(benchmark.BenchmarkOptions{ .func = struct {
        fn run() void {
            var reader = Reader.from_comptime_path(data_path);
            _ = part_two(&reader);
        }
    }.run, .warm_up_iterations = 5, .iterations = 100 });
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
