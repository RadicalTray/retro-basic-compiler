const std = @import("std");
const scanner = @import("./scanner.zig");
const parser = @import("./parser.zig");
const codegen = @import("./codegen.zig");

const example1 =
    \\10 A = 1
    \\20 S = 0
    \\30 IF 10 < A 70
    \\40 S = S + A
    \\50 A = A + 1
    \\60 GOTO 30
    \\70 PRINT S
    \\80 STOP
    \\
;

const example2 =
    \\10 A = 1
    \\20 IF 10 < A 60
    \\30 PRINT A
    \\40 A = A + 1
    \\50 GOTO 20
    \\60 STOP
;

pub fn main() !void {
    const gpa = std.heap.smp_allocator;

    // NOTE: input string must live longer than tokens
    var arena_allocator: std.heap.ArenaAllocator = .init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const tokens = try scanner.scan(arena, example1);
    // for (tokens) |t| {
    //     if (t.symbol == .newline) {
    //         std.debug.print("newline \n", .{});
    //     } else {
    //         std.debug.print("{s} ({s}) ", .{ @tagName(t.symbol), t.lexeme });
    //     }
    // }
    // std.debug.print("\n", .{});

    const lines = try parser.parse(arena, tokens);
    // for (lines) |l| {
    //     std.debug.print("{}\n", .{l}); // TODO: line custom fmt
    // }

    const codes = try codegen.genBCode(arena, lines);
    // for (0.., codes) |i, c| {
    //     std.debug.print("{} ", .{c});
    //     if (i + 1 < codes.len and codes[i + 1] == .line) {
    //         std.debug.print("\n", .{});
    //     }
    // }
    // std.debug.print("\n", .{});

    var stdout_buffer: [128]u8 = undefined;
    var stdout_w = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_w.interface;

    for (0.., codes) |i, c| {
        const nums = c.toInt();
        try stdout.print("{} {} ", .{ nums[0], nums[1] });
        if (i + 1 < codes.len and (codes[i + 1] == .line or codes[i + 1] == .eof)) {
            try stdout.print("\n", .{});
        }
    }
    try stdout.print("\n", .{});
    try stdout.flush();
}
