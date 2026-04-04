const std = @import("std");
const scanner = @import("./scanner.zig");

const example =
\\10 A = 1
\\20 S = 0
\\30 IF 10 < A 70
\\40 S = S + A
\\50 A = A + 1
\\60 GOTO 30
\\70 PRINT S
\\80 STOP
;

pub fn main() !void {
    const gpa = std.heap.smp_allocator;

    var token_arena_allocator: std.heap.ArenaAllocator = .init(gpa);
    defer token_arena_allocator.deinit();
    const token_arena = token_arena_allocator.allocator();
    const tokens = try scanner.scan(token_arena, example);
    for (tokens) |t| {
        if (t.symbol == .newline) {
            std.debug.print("newline\n", .{});
        } else {
            std.debug.print("{s} ({s})\n", .{@tagName(t.symbol), t.lexeme});
        }
    }
}
