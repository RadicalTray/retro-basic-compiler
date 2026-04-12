const std = @import("std");
const print = std.debug.print;

const scanner = @import("./scanner.zig");
const parser = @import("./parser.zig");
const parser_cyk = @import("./parser_cyk.zig");
const parser_earley = @import("./parser_earley.zig");
const codegen = @import("./codegen.zig");

const Rule = @import("Rule.zig");

pub const Result = struct {
    name: []const u8,
    success: bool,
    iterations: usize,
    time_ns: u64,

    pub fn format(r: Result, w: *std.Io.Writer) !void {
        try w.print("{s}\n", .{r.name});
        if (r.success) {
            try w.print("    Result: Passed!\n", .{});
        } else {
            try w.print("    Result: Failed!\n", .{});
        }
        try w.print("    Iterations: {}\n", .{r.iterations});
        try w.print("    Time taken: {} ms\n", .{@as(f64, @floatFromInt(r.time_ns)) / 1_000_000});
    }
};

pub fn main() !u8 {
    const gpa = std.heap.smp_allocator;

    var input_file: ?[]const u8 = null;
    {
        const args = try std.process.argsAlloc(gpa);
        var i: usize = 1; // skip exe

        if (i < args.len) {
            input_file = args[i];
            i += 1;
        } else {
            std.log.err("An input file is required!", .{});
            return 1;
        }
    }

    const input = blk: {
        if (input_file) |file_path| {
            break :blk try std.fs.cwd().readFileAlloc(gpa, file_path, std.math.maxInt(usize));
        } else {
            unreachable;
        }
    };

    // NOTE: input string must live longer than tokens
    var token_arena: std.heap.ArenaAllocator = .init(gpa);
    defer token_arena.deinit();
    const tokens = try scanner.scan(token_arena.allocator(), input);

    const iterations = 1000;

    const cyk_rules = [_]Rule{
        // START RULE FOR CYK'S PARSER
        .init(&.{
            &.{ .rule(2), .rule(3) },
        }),

        .init(&.{
            &.{ .rule(2), .rule(3) },
        }),
        .init(&.{
            &.{.symbol(.minus)},
            &.{ .rule(2), .rule(2) },
        }),
        .init(&.{
            &.{.symbol(.plus)},
            &.{ .rule(3), .rule(3) },
        }),
    };
    const cyk_result = try parser_cyk.parse(gpa, tokens, &cyk_rules, iterations);

    const earley_rules = [_]Rule{
        // START RULE FOR EARLEY'S PARSER
        .init(&.{
            &.{.rule(1)},
        }),

        .init(&.{
            &.{ .rule(2), .rule(3) },
        }),
        .init(&.{
            &.{.symbol(.minus)},
            &.{ .rule(2), .rule(2) },
        }),
        .init(&.{
            &.{.symbol(.plus)},
            &.{ .rule(3), .rule(3) },
        }),
    };
    const earley_result = try parser_earley.parse(gpa, tokens, &earley_rules, iterations);

    print("{f}", .{earley_result});
    print("\n", .{});
    print("{f}", .{cyk_result});

    return 0;
}
