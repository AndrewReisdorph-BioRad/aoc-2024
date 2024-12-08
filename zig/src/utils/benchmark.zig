const std = @import("std");

pub const BenchFunc = fn () void;

pub const BenchmarkOptions = struct { name: []const u8, max_iterations: u32 = 10000, warm_up_iterations: u32, func: BenchFunc };

fn format_microseconds_str(microseconds: f64) []u8 {
    const microseconds_in_a_second: f64 = 1_000_000;
    const microseconds_in_a_millisecond: f64 = 1_000;
    if (microseconds > microseconds_in_a_second) {
        return std.fmt.allocPrint(std.heap.page_allocator, "{d} s", .{microseconds / microseconds_in_a_second}) catch unreachable;
    } else if (microseconds > microseconds_in_a_millisecond) {
        return std.fmt.allocPrint(std.heap.page_allocator, "{d} ms", .{microseconds / microseconds_in_a_millisecond}) catch unreachable;
    }
    return std.fmt.allocPrint(std.heap.page_allocator, "{d} µs", .{microseconds}) catch unreachable;
}

pub fn benchmark(options: BenchmarkOptions) void {
    std.debug.print("========================================\n", .{});
    std.debug.print("Benchmarking: {s}\n", .{options.name});
    const warmup_begin = std.time.microTimestamp();
    std.debug.print("Warming up... {d} iterations", .{options.warm_up_iterations});
    for (0..options.warm_up_iterations) |_| {
        options.func();
    }
    const warmup_elapsed = std.time.microTimestamp() - warmup_begin;
    const warmup_str = format_microseconds_str(@as(f64, @floatFromInt(warmup_elapsed)));
    std.debug.print(" --> {s}\n", .{warmup_str});

    std.debug.print("Measuring...", .{});

    const super_begin = std.time.microTimestamp();

    var sum: i64 = 0;
    var times: [options.max_iterations]i64 = undefined;
    var iterations: usize = 0;
    const five_seconds_in_microseconds = 5_000_000;
    var total_elapsed: i64 = 0;
    while (true) {
        const begin = std.time.microTimestamp();
        options.func();
        const elapsed = std.time.microTimestamp() - begin;
        times[iterations] = elapsed;
        sum += elapsed;
        iterations += 1;
        total_elapsed = std.time.microTimestamp() - super_begin;
        if (total_elapsed > five_seconds_in_microseconds or iterations >= options.max_iterations) {
            break;
        }
    }

    const measure_str = format_microseconds_str(@as(f64, @floatFromInt(total_elapsed)));
    std.debug.print(" {d} iterations --> {s}\n", .{ iterations, measure_str });

    var min: i128 = std.math.maxInt(i64);
    var max: i128 = std.math.minInt(i64);

    for (times[0..iterations]) |time| {
        if (time > max) {
            max = time;
        }
        if (time < min) {
            min = time;
        }
    }

    const total = @as(f64, @floatFromInt(sum));
    const population_size = @as(f64, @floatFromInt(iterations));
    const mean: f64 = total / population_size;

    var sum_of_dist_squared: f64 = 0.0;
    for (times[0..iterations]) |time| {
        sum_of_dist_squared += std.math.pow(f64, (@as(f64, @floatFromInt(time)) - mean), 2);
    }
    const sigma = std.math.sqrt(sum_of_dist_squared / population_size);

    std.mem.sort(i64, times[0..iterations], {}, std.sort.asc(i64));
    const median = times[iterations / 2];

    const min_str = format_microseconds_str(@as(f64, @floatFromInt(min)));
    defer std.heap.page_allocator.free(min_str);
    const max_str = format_microseconds_str(@as(f64, @floatFromInt(max)));
    defer std.heap.page_allocator.free(max_str);
    const mean_str = format_microseconds_str(mean);
    defer std.heap.page_allocator.free(mean_str);
    const median_str = format_microseconds_str(@as(f64, @floatFromInt(median)));
    defer std.heap.page_allocator.free(median_str);
    const sigma_str = format_microseconds_str(sigma);
    defer std.heap.page_allocator.free(sigma_str);

    std.debug.print("   Min: {s}\n   Max: {s}\n  Mean: {s}\nMedian: {s}\nStdDev: {s}\n", .{ min_str, max_str, mean_str, median_str, sigma_str });
    std.debug.print("========================================\n", .{});
}
