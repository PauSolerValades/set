const std = @import("std");
const set = @import("root.zig");

pub fn main(init: std.process.Init) !void {
    
    const gpa = init.gpa;

    const repetitions: usize = 1000;
    const times = try gpa.alloc(i64, repetitions);
    defer gpa.free(times);

    const upper: u32 = 100000; 
    var B = set.Set(u32).init();
    defer B.deinit(gpa);

    for (0..@divExact(upper, 2)) |i| {
        const e: u32 = @intCast(i);
        _ = try B.add(gpa, e);
    }
    
    std.debug.print("starting benchkmark\n", .{});
    for (0..repetitions) |i| {
        
        var A = set.Set(u32).init();
        defer A.deinit(gpa);

        for (0..upper) |j| {
            const e: u32 = @intCast(j);
            _ = try A.add(gpa, @as(u32, e));
        }
    
        const startTime = std.Io.Timestamp.now(init.io, .awake);
        _ = try A.differenceUpdate(B);
        const elapsedTime = startTime.untilNow(init.io, .awake);

        times[i] = elapsedTime.toMilliseconds();
    }

    const stats: Stats = Stats.calculateFromData(times);

    std.debug.print("{s: <24}: {d:.4} +/- {d:.6} (95% CI)\n", .{ "Avg Time (ms)", stats.mean, stats.ci });
}

pub const Stats = struct {
    mean: f64,
    ci: f64,

    pub fn calculateFromData(data: []i64) Stats {
        var sum: i64 = 0;
        for (data) |v| sum += v;
        const mean: f64 = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(data.len));

        var sum_sq_diff: f64 = 0.0;
        for (data) |v| {
            const diff = @as(f64, @floatFromInt(v)) - mean;
            sum_sq_diff += diff * diff;
        }

        const variance = sum_sq_diff / @as(f64, @floatFromInt(data.len - 1));
        const std_dev = std.math.sqrt(variance);

        const margin_error = 1.96 * (std_dev / std.math.sqrt(@as(f64, @floatFromInt(data.len))));

        return Stats{ .mean = mean, .ci = margin_error };
    }
};

