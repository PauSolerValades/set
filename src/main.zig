const std = @import("std");
const set = @import("root.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    const repetitions: usize = 1000;
    
    const times_diff = try gpa.alloc(i64, repetitions);
    defer gpa.free(times_diff);
    
    const times_sym = try gpa.alloc(i64, repetitions);
    defer gpa.free(times_sym);
    
    const times_inter = try gpa.alloc(i64, repetitions);
    defer gpa.free(times_inter);

    const upper: u32 = 100000; 
    var B = set.Set(u32).init();
    defer B.deinit(gpa);

    for (0..@divExact(upper, 2)) |i| {
        const e: u32 = @intCast(i);
        _ = try B.add(gpa, e);
    }
    
    std.debug.print("starting benchmark\n", .{});
    
    for (0..repetitions) |i| {
        var A_diff = set.Set(u32).init();
        defer A_diff.deinit(gpa);
        
        var A_sym = set.Set(u32).init();
        defer A_sym.deinit(gpa);
        
        var A_inter = set.Set(u32).init();
        defer A_inter.deinit(gpa);

        for (0..upper) |j| {
            const e: u32 = @intCast(j);
            _ = try A_diff.add(gpa, e);
            _ = try A_sym.add(gpa, e);
            _ = try A_inter.add(gpa, e);
        }
    
        const start_diff = std.Io.Timestamp.now(init.io, .awake);
        _ = try A_diff.differenceUpdate(B);
        const elapsed_diff = start_diff.untilNow(init.io, .awake);
        times_diff[i] = elapsed_diff.toMilliseconds();

        const start_sym = std.Io.Timestamp.now(init.io, .awake);
        _ = try A_sym.symmetricDifferenceUpdate(gpa, B);
        const elapsed_sym = start_sym.untilNow(init.io, .awake);
        times_sym[i] = elapsed_sym.toMilliseconds();

        const start_inter = std.Io.Timestamp.now(init.io, .awake);
        _ = try A_inter.intersectionUpdate(gpa, B);
        const elapsed_inter = start_inter.untilNow(init.io, .awake);
        times_inter[i] = elapsed_inter.toMilliseconds();
    }

    const stats_diff = Stats.calculateFromData(times_diff);
    const stats_sym = Stats.calculateFromData(times_sym);
    const stats_inter = Stats.calculateFromData(times_inter);

    std.debug.print("{s: <24}: {d:.4} +/- {d:.6} (95% CI)\n", .{ "Difference (ms)", stats_diff.mean, stats_diff.ci });
    std.debug.print("{s: <24}: {d:.4} +/- {d:.6} (95% CI)\n", .{ "Sym Difference (ms)", stats_sym.mean, stats_sym.ci });
    std.debug.print("{s: <24}: {d:.4} +/- {d:.6} (95% CI)\n", .{ "Intersection (ms)", stats_inter.mean, stats_inter.ci });
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
