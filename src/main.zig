const std = @import("std");
const print = std.debug.print;

const builtin = @import("builtin");

pub fn main() !void {
    print("Build mode: {}\n", .{builtin.mode});
    print("\n", .{});

    try @import("tests/minus_plus.zig").run();
}
