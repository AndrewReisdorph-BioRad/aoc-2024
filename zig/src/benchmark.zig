const std = @import("std");

pub const BenchFunc = fn () void;

pub const BenchmarkOptions = struct { warm_up_iterations: u32, iterations: u32, func: BenchFunc };

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
    std.debug.print("Warming up... {d} iterations\n", .{options.warm_up_iterations});
    for (0..options.warm_up_iterations) |_| {
        options.func();
    }

    std.debug.print("Measuring... {d} iterations\n", .{options.iterations});

    // const super_begin = std.time.microTimestamp();

    var sum: i64 = 0;
    var times: [options.iterations:0]i64 = undefined;
    for (0..options.iterations) |i| {
        const begin = std.time.microTimestamp();
        options.func();
        const elapsed = std.time.microTimestamp() - begin;
        times[i] = elapsed;
        sum += elapsed;
    }

    // const total_elapsed = std.time.microTimestamp() - super_begin;

    var min: i128 = std.math.maxInt(i64);
    var max: i128 = std.math.minInt(i64);

    for (times) |time| {
        if (time > max) {
            max = time;
        }
        if (time < min) {
            min = time;
        }
    }

    const total = @as(f64, @floatFromInt(sum));
    const population_size = @as(f64, times.len);
    const mean: f64 = total / population_size;

    var sum_of_dist_squared: f64 = 0.0;
    for (times) |time| {
        sum_of_dist_squared += std.math.pow(f64, (@as(f64, @floatFromInt(time)) - mean), 2);
    }
    const sigma = std.math.sqrt(sum_of_dist_squared / population_size);

    std.mem.sort(i64, &times, {}, std.sort.asc(i64));
    const median = times[times.len / 2];

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

    std.debug.print("Min: {s}\nMax: {s}\nMean: {s}\nMedian: {s}\nStandard Deviation: {s}\n", .{ min_str, max_str, mean_str, median_str, sigma_str });
}
