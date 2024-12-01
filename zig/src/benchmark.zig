const std = @import("std");

pub const BenchFunc = fn () void;

pub const BenchmarkOptions = struct { warm_up_iterations: u32, iterations: u32, func: BenchFunc };

pub fn benchmark(options: BenchmarkOptions) void {
    std.debug.print("Warming up...\n", .{});
    for (0..options.warm_up_iterations) |_| {
        options.func();
    }

    std.debug.print("Measuring...\n", .{});

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

    std.debug.print("Min: {d} µs\nMax: {d} µs\nMean: {d} µs\nMedian: {d} µs\nStandard Deviation: {d} µs\n", .{ min, max, mean, median, sigma });
}
