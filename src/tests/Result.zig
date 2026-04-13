const std = @import("std");

const Result = @This();

name: []const u8,
data: []const Data,

pub const Data = struct {
    success: bool,
    iterations: usize,
    num_tokens: usize,
    time_ns: u64,

    pub fn init(success: bool, iterations: usize, num_tokens: usize, time_ns: u64) Data {
        return .{ .success = success, .iterations = iterations, .num_tokens = num_tokens, .time_ns = time_ns };
    }
};

pub fn init(name: []const u8, data: []const Data) Result {
    return .{ .name = name, .data = data };
}

pub fn format(r: Result, w: *std.Io.Writer) !void {
    try w.print("--- {s} ---\n", .{r.name});
    for (0.., r.data) |i, d| {
        if (d.success) {
            try w.print("Result: Passed!\n", .{});
        } else {
            try w.print("Result: Failed!\n", .{});
        }
        try w.print("Number of Tokens: {}\n", .{d.num_tokens});
        try w.print("Iterations: {}\n", .{d.iterations});
        const total_time_taken = @as(f64, @floatFromInt(d.time_ns)) / 1_000_000;
        try w.print("Total Time Taken: {} ms\n", .{total_time_taken});
        try w.print("Average Time Taken: {} ms\n", .{total_time_taken / @as(f64, @floatFromInt(d.iterations))});
        if (i < r.data.len - 1) try w.print("\n", .{});
    }
    try w.print("--- {s} ---\n", .{r.name});
}
