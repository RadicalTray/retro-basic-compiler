const std = @import("std");
const print = std.debug.print;

const builtin = @import("builtin");

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
    num_tokens: usize,
    time_ns: u64,

    pub fn format(r: Result, w: *std.Io.Writer) !void {
        try w.print("{s}\n", .{r.name});
        if (r.success) {
            try w.print("\tResult: Passed!\n", .{});
        } else {
            try w.print("\tResult: Failed!\n", .{});
        }
        try w.print("\tIterations: {}\n", .{r.iterations});
        try w.print("\tNumber of Tokens: {}\n", .{r.num_tokens});
        try w.print("\tTime Taken: {} ms\n", .{@as(f64, @floatFromInt(r.time_ns)) / 1_000_000});
    }
};

pub fn main() !u8 {
    const gpa = std.heap.smp_allocator;

    var iterations: usize = 10;
    var input_file: []const u8 = undefined;
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

        if (i < args.len) {
            iterations = try std.fmt.parseInt(usize, args[i], 0);
            i += 1;
        }

        if (i < args.len) {
            std.log.err("Wtf are you doing?! (Unexpected extra arguments)", .{});
            return 1;
        }
    }

    print("Build mode: {}\n", .{builtin.mode});
    print("\n", .{});

    // NOTE: input string must live longer than tokens
    const input = try std.fs.cwd().readFileAlloc(gpa, input_file, std.math.maxInt(usize));
    var token_arena: std.heap.ArenaAllocator = .init(gpa);
    defer token_arena.deinit();
    const tokens = try scanner.scan(token_arena.allocator(), input);

    print("Running CYK\n", .{});
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
    print("{f}", .{cyk_result});

    print("\n", .{});

    print("Running Earley\n", .{});
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

    return 0;
}
