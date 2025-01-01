const std = @import("std");
const Reader = @import("utils/reader.zig").Reader;
const SeekFrom = @import("utils/reader.zig").SeekFrom;
const benchmark = @import("utils/benchmark.zig");

const day = 25;
const data_path = std.fmt.comptimePrint("../data/day{d}.txt", .{day});

const SchematicKind = enum { lock, key };

const Schematic = [5]u8;

fn key_fits(key: Schematic, lock: Schematic) bool {
    for (0..key.len) |i| {
        if (key[i] > (5 - lock[i])) {
            return false;
        }
    }
    return true;
}

pub fn part_one(reader: *Reader) u64 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var locks = std.ArrayList(Schematic).init(allocator);
    var keys = std.ArrayList(Schematic).init(allocator);

    while (reader.next_char()) |indicator| {
        var schematic: Schematic = std.mem.zeroes(Schematic);
        reader.seek(SeekFrom.Current, 5);

        for (0..6) |_| {
            for (0..5) |i| {
                schematic[i] += reader.next_char().? & 1;
            }
            _ = reader.next_char();
        }

        _ = reader.next_char();

        if (indicator == '#') {
            locks.append(schematic) catch unreachable;
        } else {
            schematic[0] -= 1;
            schematic[1] -= 1;
            schematic[2] -= 1;
            schematic[3] -= 1;
            schematic[4] -= 1;

            keys.append(schematic) catch unreachable;
        }
    }

    var sum: u64 = 0;
    for (locks.items) |lock| {
        for (keys.items) |key| {
            if (key_fits(key, lock)) {
                sum += 1;
            }
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
}

test "part 1 small" {
    var reader = Reader.init(
        \\#####
        \\.####
        \\.####
        \\.####
        \\.#.#.
        \\.#...
        \\.....
        \\
        \\#####
        \\##.##
        \\.#.##
        \\...##
        \\...#.
        \\...#.
        \\.....
        \\
        \\.....
        \\#....
        \\#....
        \\#...#
        \\#.#.#
        \\#.###
        \\#####
        \\
        \\.....
        \\.....
        \\#.#..
        \\###..
        \\###.#
        \\###.#
        \\#####
        \\
        \\.....
        \\.....
        \\.....
        \\#....
        \\#.#..
        \\#.#.#
        \\#####
    );
    const result = part_one(&reader);
    try std.testing.expectEqual(3, result);
}

test "part 1 big" {
    var reader = Reader.from_comptime_path(data_path);
    const result = part_one(&reader);
    try std.testing.expectEqual(3360, result);
}
