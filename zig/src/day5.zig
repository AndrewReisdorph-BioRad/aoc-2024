const std = @import("std");
const Reader = @import("reader.zig").Reader;
const Grid = @import("grid.zig").Grid;
const Direction = @import("grid.zig").Direction;
const Position = @import("grid.zig").Position;
const benchmark = @import("benchmark.zig");

const day = 5;
const data_path = std.fmt.comptimePrint("./data/day{d}.txt", .{day});
const small_data_path = std.fmt.comptimePrint("./data/day{d}_small.txt", .{day});

fn check_page_order(pages: *std.ArrayList(u8), comes_before: []const u8) bool {
    for (pages.items) |page| {
        for (comes_before) |p| {
            if (page == p) {
                return false;
            }
        }
    }
    return true;
}

pub fn part_one_naive(reader: *Reader) u64 {
    var sum: u64 = 0;
    var map = std.AutoArrayHashMap(u8, std.ArrayList(u8)).init(std.heap.page_allocator);
    defer map.deinit();

    while (reader.next_line()) |line| {
        if (line.len == 0) {
            break;
        }
        const a = std.fmt.parseInt(u8, line[0..2], 10) catch unreachable;
        const b = std.fmt.parseInt(u8, line[3..], 10) catch unreachable;
        if (map.get(a) == null) {
            map.put(a, std.ArrayList(u8).init(std.heap.page_allocator)) catch unreachable;
        }
        map.getPtr(a).?.append(b) catch unreachable;
    }

    var pages = std.ArrayList(u8).init(std.heap.page_allocator);
    defer pages.deinit();

    while (reader.next_line()) |line| {
        pages.clearRetainingCapacity();
        var it = std.mem.split(u8, line, ",");
        var line_is_valid: bool = true;
        while (it.next()) |x| {
            const page = std.fmt.parseInt(u8, x, 10) catch unreachable;
            const comes_before = map.getPtr(page);
            if (comes_before != null and !check_page_order(&pages, comes_before.?.items)) {
                line_is_valid = false;
                break;
            }
            pages.append(page) catch unreachable;
        }

        if (line_is_valid) {
            sum += pages.items[pages.items.len / 2];
        }
    }

    var map_iter = map.iterator();
    while (map_iter.next()) |kv| {
        kv.value_ptr.deinit();
    }

    return sum;
}

pub fn part_one(reader: *Reader) u64 {
    var sum: u64 = 0;
    sum += 0;

    var map: [100]u100 = std.mem.zeroes([100]u100);
    while (reader.next_line()) |line| {
        if (line.len == 0) {
            break;
        }
        const a = std.fmt.parseInt(u8, line[0..2], 10) catch unreachable;
        const b: u8 = std.fmt.parseInt(u8, line[3..], 10) catch unreachable;
        map[a] |= @as(u100, 1) << @intCast(b);
    }

    var pages = std.ArrayList(u8).init(std.heap.page_allocator);
    defer pages.deinit();

    while (reader.next_line()) |line| {
        pages.clearRetainingCapacity();
        var it = std.mem.split(u8, line, ",");
        var line_is_valid: bool = true;
        var line_mask: u100 = 0;
        while (it.next()) |x| {
            const page = std.fmt.parseInt(u8, x, 10) catch unreachable;
            const comes_before = map[page];
            line_mask |= @as(u100, 1) << @intCast(page);
            if ((line_mask & comes_before) > 0) {
                line_is_valid = false;
                break;
            }
            pages.append(page) catch unreachable;
        }

        if (line_is_valid) {
            sum += pages.items[pages.items.len / 2];
        }
    }

    return sum;
}

fn reorder_pages(pages: []u8, map: *[100]u100) void {
    while (true) {
        var line_mask: u100 = 0;
        var valid = true;
        for (0..pages.len) |page_idx| {
            const comes_before = map[pages[page_idx]];
            line_mask |= @as(u100, 1) << @intCast(pages[page_idx]);
            if ((line_mask & comes_before) > 0) {
                // swap the current page with the previous page
                const temp = pages[page_idx];
                pages[page_idx] = pages[page_idx - 1];
                pages[page_idx - 1] = temp;
                valid = false;
                break;
            }
        }
        if (valid) {
            break;
        }
    }
}

pub fn part_two(reader: *Reader) u64 {
    var sum: u64 = 0;
    sum += 0;

    var map: [100]u100 = std.mem.zeroes([100]u100);
    while (reader.next_line()) |line| {
        if (line.len == 0) {
            break;
        }
        const a = std.fmt.parseInt(u8, line[0..2], 10) catch unreachable;
        const b: u8 = std.fmt.parseInt(u8, line[3..], 10) catch unreachable;
        map[a] |= @as(u100, 1) << @intCast(b);
    }

    var pages = std.ArrayList(u8).init(std.heap.page_allocator);
    defer pages.deinit();

    while (reader.next_line()) |line| {
        pages.clearRetainingCapacity();
        var it = std.mem.split(u8, line, ",");
        var line_is_valid: bool = true;
        var line_mask: u100 = 0;
        while (it.next()) |x| {
            const page = std.fmt.parseInt(u8, x, 10) catch unreachable;
            const comes_before = map[page];
            pages.append(page) catch unreachable;
            line_mask |= @as(u100, 1) << @intCast(page);
            if ((line_mask & comes_before) > 0) {
                line_is_valid = false;
                reorder_pages(pages.items, &map);
            }
        }

        if (line_is_valid) {
            continue;
        }

        sum += pages.items[pages.items.len / 2];
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
    try std.testing.expect(result == 143);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 4774);
}

test "part 2 small" {
    var reader = Reader.from_comptime_path(small_data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 123);
}

test "part 2 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_two(&reader);
    std.debug.print("\nResult: {}\n", .{result});
    try std.testing.expect(result == 6004);
}
